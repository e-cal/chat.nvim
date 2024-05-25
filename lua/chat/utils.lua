local M = {}

M.ensureUrlProtocol = function(str)
	if M.startsWith(str, "https://") or M.startsWith(str, "http://") then
		return str
	end

	return "https://" .. str
end

M.gq_chat = function(bufnr)
	local config = require("chat.config")
	if not config.opts.auto_gq then
		return
	end

	vim.api.nvim_buf_call(bufnr, function()
		local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local start_line = 1
		local in_code_block = false

		for i, line in ipairs(buf_lines) do
			if line:match("^```") then
				if in_code_block then
					-- Ending a code block
					start_line = i + 1
				else
					-- Starting a code block, format the previous non-code section if any
					if i > start_line then
						vim.cmd("normal " .. start_line .. "GV" .. (i - 1) .. "Ggq")
					end
				end
				in_code_block = not in_code_block
			elseif not in_code_block and i == #buf_lines then
				-- If we're at the end of the file, format the last section
				vim.cmd("normal " .. start_line .. "GV" .. i .. "Ggq")
			end
		end

		vim.cmd("normal! G")
	end)
end

M.yank_assistant_code = function(bufnr)
	local config = require("chat.config")
	-- yank code into register c from last assistant message
	-- (between last assistant deliminator and the user deliminator at the end of the file)
	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local last_assistant_idx = -1
	local user_delimiter_idx = -1
	for i = #buf_lines, 1, -1 do
		if buf_lines[i] == config.opts.delimiters.user and user_delimiter_idx == -1 then
			user_delimiter_idx = i
		elseif buf_lines[i] == config.opts.delimiters.assistant and last_assistant_idx == -1 then
			last_assistant_idx = i
			break
		end
	end

	if last_assistant_idx ~= -1 and user_delimiter_idx ~= -1 and user_delimiter_idx > last_assistant_idx then
		local code_block_start = -1
		local code_block_end = -1
		local in_code_block = false
		for i = last_assistant_idx + 1, user_delimiter_idx - 1 do
			if buf_lines[i]:match("^```") then
				if in_code_block then
					code_block_end = i
					break
				else
					code_block_start = i
				end
				in_code_block = not in_code_block
			end
		end

		if code_block_start ~= -1 and code_block_end ~= -1 then
			vim.cmd("silent " .. (code_block_start + 1) .. "," .. (code_block_end - 1) .. "y c")
		end
	end
end

return M
