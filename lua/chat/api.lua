local config = require("chat.config")

local M = {}

local function exec(cmd, args, on_stdout, on_complete)
	local stdout = vim.loop.new_pipe()
	local function on_stdout_read(_, chunk)
		if chunk then
			vim.schedule(function()
				on_stdout(chunk)
			end)
		end
	end

	local stderr = vim.loop.new_pipe()
	local stderr_chunks = {}
	local function on_stderr_read(_, chunk)
		if chunk then
			table.insert(stderr_chunks, chunk)
		end
	end

	local handle, err

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

-- Provider API utils

local function get_provider(model)
	if model:find("gpt") then
		return "openai"
	elseif model:find("claude") then
		return "anthropic"
	elseif model:find("deepseek") then
		return "deepseek"
	else
		return "groq"
	end
end

local function get_api_key(provider)
	local api_key
	local api_key_config = config.opts.api_keys[provider]
	if type(api_key_config) == "string" then
		api_key = api_key_config
	else
		api_key = api_key_config()
	end
	if type(api_key) ~= "string" or api_key == "" then
		print("Error: Missing " .. provider .. " API key")
	end
	return api_key
end

local function get_provider_url(provider)
	if provider == "openai" then
		return "https://api.openai.com/v1/chat/completions"
	elseif provider == "anthropic" then
		return "https://api.anthropic.com/v1/messages"
    elseif provider == "deepseek" then
        return "https://api.deepseek.com/chat/completions"
	elseif provider == "groq" then
		return "https://api.groq.com/openai/v1/chat/completions"
	end
end

local function get_headers(provider)
	local headers = { ["Content-Type"] = "application/json" }
	if provider == "anthropic" then
		headers["anthropic-version"] = "2023-06-01" -- https://docs.anthropic.com/en/api/versioning
		headers["x-api-key"] = get_api_key(provider)
	else
		headers["Authorization"] = "Bearer " .. get_api_key(provider)
	end
	return headers
end

-- Request logic

local function get_curl_args(messages, model, temp, stream)
	local provider = get_provider(model)
	local url = get_provider_url(provider)
	local headers = get_headers(provider)

	local data = { temperature = temp }
	data["stream"] = stream

	if provider == "anthropic" then
		data["max_tokens"] = 4096

		if model == "claude-3.5-sonnet" then
			model = "claude-3-5-sonnet"
		end
		-- map model to api model name (https://docs.anthropic.com/en/docs/about-claude/models)
		local model_suffix = {
			["claude-3-haiku"] = "20240307",
			["claude-3-sonnet"] = "20240229",
			["claude-3-opus"] = "20240229",
			["claude-3-5-sonnet"] = "20240620",
		}
		if model_suffix[model] then
			model = model .. "-" .. model_suffix[model]
		end

		-- supply system message as separate parameter
		local first_message = messages[1]
		if first_message.role == "system" then
			data["system"] = first_message.content
			table.remove(messages, 1)
		end
	elseif provider == "groq" then
		-- map model to api model name (https://console.groq.com/docs/models)
		local model_suffix = {
			["llama3-8b"] = "8192",
			["llama3-70b"] = "8192",
			["mixtral"] = "8x7b-32768",
			["mixtral-8x7b"] = "32768",
			["gemma-7b"] = "it",
		}
		if model_suffix[model] then
			model = model .. "-" .. model_suffix[model]
		end
	end
	data["messages"] = messages
	data["model"] = model

	local curl_args = { "--silent", "--show-error", url }
	if stream then
		table.insert(curl_args, "--no-buffer")
	end

	for k, v in pairs(headers) do
		table.insert(curl_args, "--header")
		table.insert(curl_args, string.format("%s: %s", k, v))
	end

	table.insert(curl_args, "--data")
	table.insert(curl_args, vim.json.encode(data))

	return curl_args
end

local function handle_stream_chunk(chunk, bufnr, raw_chunks)
	for chunk_json in chunk:gmatch("[^\n]+") do
		local raw_json = string.gsub(chunk_json, "^data: ", "")

		table.insert(raw_chunks, raw_json)

		local ok, chunk_data = pcall(vim.json.decode, raw_json)
		if not ok then
			goto continue
		end

		local chunk_content
		if chunk_data.choices ~= nil then -- openai/groq api
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

M.request = function(messages, model, temp, bufnr, on_complete, stream_response)
	local args = get_curl_args(messages, model, temp, stream_response or false)

	if stream_response then
		local raw_chunks = {}
		local on_stdout_chunk = function(chunk)
			handle_stream_chunk(chunk, bufnr, raw_chunks)
		end

		local _on_complete = function(err, _)
			handle_complete(err, raw_chunks, on_complete)
		end

		exec("curl", args, on_stdout_chunk, _on_complete)
	else
		local on_stdout = function(response_body)
			local ok, response = pcall(vim.json.decode, response_body)
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
