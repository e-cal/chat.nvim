local config = require("chat.config")

local M = {}

local function get_api_key(provider)
	local api_key_config = config.opts.api_keys[provider]
	local api_key = type(api_key_config) == "function" and api_key_config() or api_key_config
	if type(api_key) ~= "string" or api_key == "" then
		vim.notify("Error: Missing " .. provider .. " API key", vim.log.levels.ERROR)
	end
	return api_key
end

local function default_headers(provider)
	local api_key = get_api_key(provider)
	return {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. api_key,
	}
end

--[[
provider = {
    url:  string provider chat completions url
    match_pattern: string pattern to match for model names
    headers: custom headers for the provider
    prepare_data: function (params: data, model) to modify data before sending (if provider doesn't expect standard openai data format)
}
]]
local providers = {
	openrouter = { url = "https://openrouter.ai/api/v1/chat/completions" },
	openai = {
		url = "https://api.openai.com/v1/chat/completions",
		match_pattern = "gpt",
	},
	anthropic = {
		url = "https://api.anthropic.com/v1/messages",
		match_pattern = "claude",
		headers = function()
			return {
				["Content-Type"] = "application/json",
				["anthropic-version"] = "2023-06-01",
				["x-api-key"] = get_api_key("anthropic"),
			}
		end,
		prepare_data = function(data, _)
			data.max_tokens = 4096
			if data.messages[1].role == "system" then
				data.system = data.messages[1].content
				table.remove(data.messages, 1)
			end
			return data
		end,
	},
	deepseek = { url = "https://api.deepseek.com/chat/completions" },
	groq = { url = "https://api.groq.com/openai/v1/chat/completions" },
	cerebras = { url = "https://api.cerebras.ai/v1/chat/completions" },
	hyperbolic = { url = "https://api.hyperbolic.xyz/v1/chat/completions" },
	hyperbolic_base = {
		url = "https://api.hyperbolic.xyz/v1/completions",
		prepare_data = function(data, _)
			local prompt = ""
			for _, message in ipairs(data.messages) do
				if message.content ~= nil then
					prompt = prompt .. message.content .. "\n\n"
				end
			end
			data.prompt = prompt
			data.messages = nil
			data.max_tokens = config.opts.inline.max_tokens
			return data
		end,
		headers = function()
			return default_headers("hyperbolic")
		end,
	},
	fireworks = {
		url = "https://api.fireworks.ai/inference/v1/chat/completions",
		prepare_data = function(data, model)
			data.model = "accounts/fireworks/models/" .. model
			return data
		end,
	},
	entropix = {
		url = "127.0.0.1:1337/v1/chat/completions",
		headers = function()
			return {
				["Content-Type"] = "application/json",
			}
		end,
	},
}

local function exec(cmd, args, on_stdout, on_complete)
	local stdout = vim.loop.new_pipe()
	local stderr = vim.loop.new_pipe()
	local stderr_chunks = {}
	local handle, err

	local function on_stdout_read(_, chunk)
		if chunk then
			vim.schedule(function()
				local should_stop = on_stdout(chunk)
				if should_stop and handle then
					handle:kill(15)
				end
			end)
		end
	end

	local function on_stderr_read(_, chunk)
		if chunk then
			table.insert(stderr_chunks, chunk)
		end
	end

	handle, err = vim.loop.spawn(cmd, {
		args = args,
		stdio = { nil, stdout, stderr },
	}, function(code)
		stdout:close()
		stderr:close()
		handle:close()

		vim.schedule(function()
			if code ~= 0 then
				on_complete(vim.trim(table.concat(stderr_chunks, "")))
			else
				on_complete()
			end
		end)
	end)

	if not handle then
		on_complete(cmd .. " could not be started: " .. err)
	else
		stdout:read_start(on_stdout_read)
		stderr:read_start(on_stderr_read)
	end
end

local function get_provider(model)
	for provider_name, provider_data in pairs(providers) do
		local model_map = config.model_maps[provider_name]
		if model_map and model_map[model] ~= nil then
            -- vim.notify(string.format("Using %s as provider for %s", provider_name, model))
			return provider_name
		elseif provider_data.match_pattern and model:find(provider_data.match_pattern) then
            -- vim.notify(string.format("Using %s as provider for %s", provider_name, model))
			return provider_name
		end
	end
    -- print(string.format("Missing provider for %s. Using openrouter as fallback.", model))
    -- vim.notfiy(string.format("Missing provider for %s. Using openrouter as fallback.", model))
	return "openrouter"
end

local function get_curl_args(messages, model, temp, save_path, stream)
	local provider_name = get_provider(model)
	if config.opts.print_provider then
		vim.notify(string.format("Using %s via %s", model, provider_name))
	end
	local provider = providers[provider_name]
	local url = provider.url
	local headers
	if provider.headers then
		headers = provider.headers()
	else
		headers = default_headers(provider_name)
	end

	local model_map = config.model_maps[provider_name]
	if model_map then
		for key, value in pairs(model_map) do
			if model == key or model == value then
				model = value
				break
			end
		end
	end

	local data = {
		stream = stream,
		messages = messages,
		model = model,
	}
	if temp ~= nil then
		data.temperature = temp
	end
	if save_path then
		data.save_path = save_path
	end

	if provider.prepare_data then
		data = provider.prepare_data(data, model)
	end

	local curl_args = { "--silent", "--show-error", url }
	if stream then
		table.insert(curl_args, "--no-buffer")
	end

	for k, v in pairs(headers) do
		table.insert(curl_args, "--header")
		table.insert(curl_args, string.format("%s: %s", k, v))
	end

	-- P(data)
	table.insert(curl_args, "--data")
	table.insert(curl_args, vim.json.encode(data))

	return curl_args
end

local function handle_stream_chunk(chunk, bufnr, raw_chunks)
	for chunk_json in chunk:gmatch("[^\n]+") do
		local raw_json = string.gsub(chunk_json, "^data: ", "")
		-- print(raw_json)
		table.insert(raw_chunks, raw_json)

		local ok, chunk_data = pcall(vim.json.decode, raw_json)
		if not ok then
			goto continue
		end

		local chunk_content
		if chunk_data.choices ~= nil then -- openai-style api
			local chunk_delta = chunk_data.choices[1].delta
			chunk_content = (
				(not chunk_delta.content or chunk_delta.content == vim.NIL) and chunk_delta.reasoning_content
			) or chunk_delta.content
		elseif chunk_data.type == "content_block_delta" then -- anthropic api
			chunk_content = chunk_data.delta.text
		end
		if chunk_content == nil then
			goto continue
		end

		local current_line = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1] or ""
		current_line = current_line .. chunk_content

		local lines = vim.split(current_line, "\n", true)
		vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, { lines[1] })
		if #lines > 1 then
			vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, vim.list_slice(lines, 2))
		end

		::continue::
	end
end

local function handle_complete(err, raw_chunks, on_complete)
	local total_message = table.concat(raw_chunks, "")
	local ok, json = pcall(vim.json.decode, total_message)
	if ok then
		if json.error ~= nil then
			on_complete(json.error.message, nil)
			return
		end
	end
	on_complete(err, nil)
end

M.request = function(params)
	assert(params.messages, "messages is required")
	assert(params.model, "model is required")
	local args =
		get_curl_args(params.messages, params.model, params.temp, params.save_path, params.stream_response or false)
	-- print("request")
	-- P(args)
	local stream_response = params.stream_response or false
	local bufnr = params.bufnr
	local on_complete = params.on_complete
	local on_chunk = params.on_chunk

	if stream_response then
		local raw_chunks = {}
		local on_stdout_chunk = function(chunk)
			-- print("on_stdout_chunk")
			-- P(chunk)

			if vim.g.chat_stop_generation then
				vim.g.chat_stop_generation = false
				return true
			end
			if on_chunk then
				-- print("using provided on_chunk function")
				on_chunk(nil, chunk)
			else
				handle_stream_chunk(chunk, bufnr, raw_chunks)
			end
		end

		local _on_complete = function(err, _)
			handle_complete(err, raw_chunks, on_complete)
		end

		exec("curl", args, on_stdout_chunk, _on_complete)
	else
		local on_stdout = function(response_body)
			local ok, response = pcall(vim.json.decode, response_body)
			-- P(response)
			if not ok then
				on_complete("Failed to parse response JSON: " .. response_body)
				return
			end
			if response.error then
				on_complete("Request error: " .. response.error.message)
				return
			end
			on_complete(nil, response)
		end

		exec("curl", args, on_stdout, on_complete)
	end
end

return M
