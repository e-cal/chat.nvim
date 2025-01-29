local config = require("chat.config")

local M = {}

local function get_api_key(provider)
	local api_key_config = config.opts.api_keys[provider]
	local api_key = type(api_key_config) == "function" and api_key_config() or api_key_config
	if type(api_key) ~= "string" or api_key == "" then
		print("Error: Missing " .. provider .. " API key")
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
    models: string to match for model names | table list of models (model map is used to enumerate models if not present)
    model_map: table map model abbreviation to api model name
    headers: custom headers for the provider
    prepare_data: function (params: data, model) to modify data before sending (if provider doesn't expect standard openai data format)
}
]]
local providers = {
	entropix = {
		url = "127.0.0.1:1337/v1/chat/completions",
		model_map = {
			["entropix"] = "llama-1b",
			["llama-1b"] = "llama-1b",
			["smollm"] = "smollm",
		},
		headers = function()
			return {
				["Content-Type"] = "application/json",
			}
		end,
	},
	openai = {
		url = "https://api.openai.com/v1/chat/completions",
		models = "gpt",
	},
	anthropic = {
		url = "https://api.anthropic.com/v1/messages",
		models = "claude",
		model_map = {
			-- 3 aliases
			["claude-3-haiku"] = "claude-3-haiku-20240307",
			["claude-3-sonnet"] = "claude-3-sonnet-20240229",
			["claude-3-opus"] = "claude-3-opus-20240229",
			-- 3.5 aliases
			["claude-3.5-sonnet"] = "claude-3-5-sonnet-20240620",
			["claude-3.5-sonnet-new"] = "claude-3-5-sonnet-20241022",
			["claude-3.5-sonnet-latest"] = "claude-3-5-sonnet-latest",
			-- ["claude-3.5-haiku"] = "claude-3-5-haiku-latest",
			-- versionless aliases
			["claude"] = "claude-3-5-sonnet-20240620",
			["sonnet"] = "claude-3-5-sonnet-20240620",
			["sonnet-new"] = "claude-3-5-sonnet-20241022",
			["sonnet-latest"] = "claude-3-5-sonnet-latest",
		},
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
	deepseek = {
		url = "https://api.deepseek.com/chat/completions",
		model_map = {
            ["r1"] = "deepseek-reasoner",
            ["deepseek-v3"] = "deepseek-chat",
            ["deepseek-chat"] = "deepseek-chat",
        },
	},
	groq = {
		url = "https://api.groq.com/openai/v1/chat/completions",
		model_map = {
			["llama3-8b"] = "llama3-8b-8192",
			["llama3-70b"] = "llama3-70b-8192",
			["mixtral"] = "mixtral-8x7b-32768",
			["mixtral-8x7b"] = "mixtral-8x7b-32768",
			["gemma-7b"] = "gemma-7b-it",
			["llama-3.1-8b"] = "llama-3.1-8b-instant",
			["llama-3.1-70b"] = "llama-3.1-70b-versatile",
		},
	},
	cerebras = {
		url = "https://api.cerebras.ai/v1/chat/completions",
		model_map = {
			["cerebras/llama-3.1-8b"] = "llama-3.1-8b",
			["cerebras/llama-3.1-70b"] = "llama-3.1-70b",
			["cerebras/llama-3.3-70b"] = "llama-3.3-70b",
		},
	},
	topology = {
		url = "https://topologychat.com/api/chat/completions",
		models = "topology",
		prepare_data = function(data, model)
			-- TODO: this should be managed the same as api keys using config probably
			local f = assert(io.open(os.getenv("HOME") .. "/.cache/clm-default-partition", "r"))
			local partition_id = string.gsub(f:read("*all"), "\n", "")
			f:close()
			data.partition_id = partition_id
			return data
		end,
	},
	fireworks = {
		url = "https://api.fireworks.ai/inference/v1/chat/completions",
		model_map = {
			["fireworks/llama-3.1-8b"] = "llama-v3p1-8b-instruct",
			["fireworks/llama-3.1-70b"] = "llama-v3p1-70b-instruct",
			["fireworks/llama-3.1-405b"] = "llama-v3p1-405b-instruct",
		},
		prepare_data = function(data, model)
			data.model = "accounts/fireworks/models/" .. model
			return data
		end,
	},
	hyperbolic = {
		url = "https://api.hyperbolic.xyz/v1/chat/completions",
		model_map = {
			["llama-405b"] = "meta-llama/Meta-Llama-3.1-405B-Instruct",
			["llama-3.1-405b"] = "meta-llama/Meta-Llama-3.1-405B-Instruct",
			["llama-3.1-70b-bf16"] = "meta-llama/Meta-Llama-3.1-70B-Instruct",
			["llama-3.1-8b-bf16"] = "meta-llama/Meta-Llama-3.1-8B-Instruct",
			["deepseek"] = "deepseek-ai/DeepSeek-V2.5",
		},
	},
	hyperbolic_base = {
		url = "https://api.hyperbolic.xyz/v1/completions",
		model_map = {
			["llama-3.1-405b-base"] = "meta-llama/Meta-Llama-3.1-405B",
			["llama-3.1-405b-fp8-base"] = "meta-llama/Meta-Llama-3.1-405B-FP8",
		},
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
	openrouter = { -- fallback
		url = "https://openrouter.ai/api/v1/chat/completions",
		model_map = {
			["openrouter/llama-3.1-405b"] = "meta-llama/llama-3.1-405b-instruct",
			["nous-hermes"] = "nousresearch/hermes-3-llama-3.1-405b",
			["o1"] = "openai/o1-preview",
			["o1-mini"] = "openai/o1-mini",
			["openrouter/r1"] = "deepseek/deepseek-r1",
		},
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
		if
			type(provider_data.models) == "table"
			and (provider_data.models[model] or vim.tbl_contains(vim.tbl_keys(provider_data.models), model))
		then
			return provider_name
		elseif type(provider_data.models) == "string" and model:find(provider_data.models) then
			return provider_name
		elseif
			provider_data.model_map
			and (provider_data.model_map[model] or vim.tbl_contains(vim.tbl_keys(provider_data.model_map), model))
		then
			return provider_name
		end
	end
	-- print("[chat.nvim] Missing provider for " .. model .. ". Using openrouter as fallback.")
	return "openrouter"
end

-- Request logic

local function get_curl_args(messages, model, temp, save_path, stream)
	local provider_name = get_provider(model)
	local provider = providers[provider_name]
	local url = provider.url
	local headers
	if provider.headers then
		headers = provider.headers()
	else
		headers = default_headers(provider_name)
	end

	if provider.model_map then
		for key, value in pairs(provider.model_map) do
			if model == key or model == value then
				model = value
				break
			end
		end
	end

	local data = {
		temperature = temp,
		stream = stream,
		messages = messages,
		model = model,
	}
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
			chunk_content = chunk_data.choices[1].delta.content
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

-- M.request = function(messages, model, temp, save_path, bufnr, on_complete, stream_response, on_chunk)
M.request = function(params)
	assert(params.messages, "messages is required")
	assert(params.model, "model is required")
	assert(params.temp, "temp is required")
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
