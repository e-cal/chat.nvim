local config = require("chat.config")

local M = {}

local function log_debug(message)
	if not config.opts.debug then
		return
	end
	local log_file = io.open("/tmp/chat-nvim-debug.log", "a")
	if log_file then
		log_file:write(os.date("%Y-%m-%d %H:%M:%S") .. " [api.lua] " .. message .. "\n")
		log_file:close()
	end
end

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
		["X-Title"] = "chat.nvim",
		["HTTP-Referer"] = "https://github.com/e-cal/chat.nvim",
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
		local model_aliases = config.model_aliases[provider_name]
		if model_aliases and model_aliases[model] ~= nil then
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

local function get_curl_args(messages, model, temp, reasoning, stream)
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

	local model_map = config.model_aliases[provider_name]
	if model_map then
		for key, value in pairs(model_map) do
			if model == key or model == value then
				model = value
				break
			end
		end
	end

	-- Transform messages to include reasoning when present
	local api_messages = {}
	for _, msg in ipairs(messages) do
		if msg.reasoning_details then
			-- Pass complete reasoning_details object as per OpenRouter docs
			table.insert(api_messages, {
				role = msg.role,
				content = msg.content,
				reasoning_details = msg.reasoning_details,
			})
		elseif msg.reasoning_content then
			-- Fallback: manual content array format
			local content_array = {
				{
					type = "reasoning",
					reasoning = msg.reasoning_content.reasoning,
				},
				{
					type = "text",
					text = msg.content,
				},
			}
			if msg.reasoning_content.signature then
				content_array[1].signature = msg.reasoning_content.signature
			end
			table.insert(api_messages, {
				role = msg.role,
				content = content_array,
			})
		else
			-- Regular message without reasoning
			table.insert(api_messages, {
				role = msg.role,
				content = msg.content,
			})
		end
	end

	local data = {
		stream = stream,
		messages = api_messages,
		model = model,
	}
	if temp ~= nil then
		data.temperature = temp
	end

	-- Only apply reasoning parameter for openrouter provider
	if reasoning ~= nil and provider_name == "openrouter" then
		-- Map simple string values to effort levels
		local reasoning_map = {
			high = "high",
			medium = "medium",
			low = "low",
			min = "minimal",
			minimal = "minimal",
			none = "none",
		}
		local effort = reasoning_map[reasoning:lower()]
		if effort and effort ~= "none" then
			data.reasoning = { effort = effort }
		end
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

	if config.opts.debug then
		log_debug("Request data: " .. vim.inspect(data))
	end
	table.insert(curl_args, "--data")
	table.insert(curl_args, vim.json.encode(data))

	return curl_args
end

local function handle_stream_chunk(chunk, bufnr, raw_chunks, state)
	for chunk_json in chunk:gmatch("[^\n]+") do
		local raw_json = string.gsub(chunk_json, "^data: ", "")
		table.insert(raw_chunks, raw_json)

		local ok, chunk_data = pcall(vim.json.decode, raw_json)
		if not ok then
			goto continue
		end

		local function check_valid(content)
			return content ~= nil and content ~= vim.NIL and content ~= ""
		end

		local chunk_content = nil
		if chunk_data.choices ~= nil then
			local chunk_delta = chunk_data.choices[1].delta

			-- Check for signature in reasoning_details
			if chunk_delta.reasoning_details and type(chunk_delta.reasoning_details) == "table" then
				for _, detail in ipairs(chunk_delta.reasoning_details) do
					if detail.signature and detail.signature ~= "" then
						state.reasoning_signature = detail.signature
						-- Close reasoning block and write signature comment
						if state.reasoning_started and not state.reasoning_finished then
							state.reasoning_finished = true
							vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { 
								"````",
								"<!-- REASONING_SIGNATURE: " .. detail.signature .. " -->",
								"",
							})
							-- Store the complete reasoning_details object
							state.reasoning_details_obj = chunk_delta.reasoning_details
						end
						goto continue
					end
				end
			end

			-- Stream reasoning text as it arrives
			if chunk_delta.reasoning and check_valid(chunk_delta.reasoning) then
				-- First reasoning chunk - write the opening code fence
				if not state.reasoning_started then
					state.reasoning_started = true
					vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, { "````reasoning", "" })
				end
				-- Write reasoning chunk directly to buffer
				chunk_content = chunk_delta.reasoning
			elseif check_valid(chunk_delta.content) then
				-- First content chunk means reasoning is complete (if no signature came)
				if state.reasoning_started and not state.reasoning_finished then
					-- Close the reasoning code block
					state.reasoning_finished = true
					vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "````", "", "" })
				end
				chunk_content = chunk_delta.content
			end
		elseif chunk_data.type == "content_block_delta" then
			chunk_content = chunk_data.delta.text
		end
		if chunk_content == nil or type(chunk_content) == "userdata" then
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

local function handle_complete(err, raw_chunks, on_complete, state)
	-- Use the reasoning_details object we stored during streaming (has complete signature)
	local reasoning_details = state.reasoning_details_obj

	-- If we didn't capture it during streaming, try to find it in chunks
	if not reasoning_details then
		for i = #raw_chunks, 1, -1 do
			local ok, chunk_data = pcall(vim.json.decode, raw_chunks[i])
			if ok then
				if config.opts.debug and chunk_data.choices then
					log_debug("Chunk " .. i .. " structure: " .. vim.inspect(chunk_data.choices[1]))
				end

				-- Check in choices
				if chunk_data.choices and chunk_data.choices[1] then
					local choice = chunk_data.choices[1]
					-- Check message (final chunk in streaming)
					if choice.message and choice.message.reasoning_details then
						reasoning_details = choice.message.reasoning_details
						if config.opts.debug then
							log_debug("Found reasoning_details in message")
						end
						break
					end
					-- Check delta (streaming chunks with signature)
					if choice.delta and choice.delta.reasoning_details then
						for _, detail in ipairs(choice.delta.reasoning_details) do
							if detail.signature and detail.signature ~= "" then
								reasoning_details = choice.delta.reasoning_details
								if config.opts.debug then
									log_debug("Found reasoning_details with signature in delta")
								end
								break
							end
						end
					end
				end
			end
		end
	end

	-- Check for errors
	local total_message = table.concat(raw_chunks, "")
	local ok, json = pcall(vim.json.decode, total_message)
	if ok and json.error ~= nil then
		on_complete(json.error.message, nil)
		return
	end

	if config.opts.debug then
		log_debug("handle_complete returning reasoning_details: " .. vim.inspect(reasoning_details))
	end

	on_complete(err, reasoning_details)
end

M.request = function(params)
	assert(params.messages, "messages is required")
	assert(params.model, "model is required")
	local args =
		get_curl_args(params.messages, params.model, params.temp, params.reasoning, params.stream_response or false)
	if config.opts.debug then
		log_debug("Request args: " .. vim.inspect(args))
	end
	local stream_response = params.stream_response or false
	local bufnr = params.bufnr
	local on_complete = params.on_complete
	local on_chunk = params.on_chunk

	if stream_response then
		local raw_chunks = {}
		local state = {}
		local on_stdout_chunk = function(chunk)
			if config.opts.debug then
				log_debug("Received chunk: " .. vim.inspect(chunk))
			end

			if vim.g.chat_stop_generation then
				vim.g.chat_stop_generation = false
				return true
			end
			if on_chunk then
				if config.opts.debug then
					log_debug("Using provided on_chunk function")
				end
				on_chunk(nil, chunk)
			else
				handle_stream_chunk(chunk, bufnr, raw_chunks, state)
			end
		end

		local _on_complete = function(err, _)
			if err then
				on_complete(err, nil)
			else
				handle_complete(err, raw_chunks, on_complete, state)
			end
		end

		exec("curl", args, on_stdout_chunk, _on_complete)
	else
		local on_stdout = function(response_body)
			local ok, response = pcall(vim.json.decode, response_body)
			if config.opts.debug then
				log_debug("Response: " .. vim.inspect(response))
			end
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
