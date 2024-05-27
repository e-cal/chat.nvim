local config = require("chat.config")

local M = {}

M.ensureUrlProtocol = function(str)
	if M.startsWith(str, "https://") or M.startsWith(str, "http://") then
		return str
	end

	return "https://" .. str
end

-- Start nil and set later to avoid circular dependencies
M.providers = nil
M.current_provider = nil
local function get_providers()
	return {
		openai = require("chat.providers.openai"),
	}
end

local function get_provider(model)
	if model:find("gpt") then
		return "openai"
	elseif model:find("claude") then
		return "anthropic"
	else
		return "groq"
	end
end

M.request = function(messages, model, bufnr, on_complete)
	M.providers = M.providers or get_providers()
	local provider = get_provider(model)
	M.providers[provider].request(messages, model, bufnr, on_complete)
end

M.stream = function(messages, model, bufnr, on_complete)
	M.providers = M.providers or get_providers()
	local provider = get_provider(model)
	M.providers[provider].stream(messages, model, bufnr, on_complete)
end

M.exec = function(cmd, args, on_stdout, on_complete)
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

return M
