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

local function prepare_data(messages, model, temp)
	local data = {
		model = model,
		messages = messages,
        temperature = temp,
	}
	return data
end

M.request = function(messages, model, bufnr, on_complete)
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

	local data = prepare_data(messages, model)
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

M.stream = function(messages, model, temp, bufnr, on_complete)
	local raw_chunks = {}
	local response_body = ""

	local on_stdout_chunk = function(chunk)
		for chunk_json in chunk:gmatch("[^\n]+") do
			local raw_json = string.gsub(chunk_json, "^data: ", "")

			table.insert(raw_chunks, raw_json)
			local ok, chunk_data = pcall(vim.json.decode, raw_json)
			if not ok then
				goto continue
			end

			-- drill down data, checking for empty values
			chunk_data = chunk_data.choices
			if chunk_data == nil then
				goto continue
			end
			chunk_data = chunk_data[1]
			if chunk_data == nil then
				goto continue
			end
			chunk_data = chunk_data.delta
			if chunk_data == nil then
				goto continue
			end

			local chunk_content = chunk_data.content
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

	local data = prepare_data(messages, model, temp)
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
