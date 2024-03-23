local config = require("chat.config")
local api = require("chat.api")

local M = {}

local function get_openai_api_key()
	local openai_api_key
	if type(config.opts.openai_api_key) == "string" then
		openai_api_key = config.opts.openai_api_key
	else
		openai_api_key = config.opts.openai_api_key()
	end
	return openai_api_key
end

local openai_url = "https://api.openai.com/v1/chat/completions"

local function get_headers()
	return {
		["Content-Type"] = "application/json",
		["Authorization"] = "Bearer " .. get_openai_api_key(),
	}
end

local function prepare_data(messages)
	return {
		model = config.opts.openai_model,
		messages = messages,
	}
end

M.request = function(messages, bufnr, on_complete)
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

	local data = prepare_data(messages)
	local headers = get_headers()

	local args = {
		"--silent",
		"--show-error",
		openai_url,
	}
	for k, v in pairs(headers) do
		table.insert(args, "--header")
		table.insert(args, string.format("%s: %s", k, v))
	end
	table.insert(args, "--data")
	table.insert(args, vim.json.encode(data))
	api.exec("curl", args, on_stdout, on_complete)
end

M.stream = function(messages, bufnr, on_complete)
	local raw_chunks = {}
	local on_stdout_chunk = function(chunk)
		for line in chunk:gmatch("[^\n]+") do
			local raw_json = string.gsub(line, "^data: ", "")

			table.insert(raw_chunks, raw_json)
			local ok, path = pcall(vim.json.decode, raw_json)
			if not ok then
				goto continue
			end

			path = path.choices
			if path == nil then
				goto continue
			end
			path = path[1]
			if path == nil then
				goto continue
			end
			path = path.delta
			if path == nil then
				goto continue
			end
			path = path.content
			if path == nil then
				goto continue
			end

			local current_line = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1] or ""
			current_line = current_line .. path

			local lines = vim.split(current_line, "\n", true)
			if #lines > 1 then
				vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, { lines[1] })
				vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, vim.list_slice(lines, 2))
			else
				vim.api.nvim_buf_set_lines(bufnr, -2, -1, false, { current_line })
			end

			::continue::
		end
	end

	local _on_complete = function(err, _)
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

	local data = prepare_data(messages)
	data["stream"] = true
	local headers = get_headers()

	local args = {
		"--silent",
		"--show-error",
		"--no-buffer",
		openai_url,
	}
	for k, v in pairs(headers) do
		table.insert(args, "--header")
		table.insert(args, string.format("%s: %s", k, v))
	end
	table.insert(args, "--data")
	table.insert(args, vim.json.encode(data))

	api.exec("curl", args, on_stdout_chunk, _on_complete)
end

return M
