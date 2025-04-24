local config = require("chat.config")

local M = {}

M.yank_code = function()
	local node = vim.treesitter.get_node()
	if not node then
		return
	end

	while node:type() ~= "fenced_code_block" and node:parent() do
		node = node:parent()
	end

	if node:type() == "fenced_code_block" then
		for child in node:iter_children() do
			if child:type() == "code_fence_content" then
				local start_row, start_col, end_row, end_col = child:range()
				local content = vim.api.nvim_buf_get_text(0, start_row, start_col, end_row, end_col, {})
				vim.fn.setreg(config.opts.code_register, table.concat(content, "\n"))
				print("[chat.nvim] yanked code")
				return
			end
		end
	end
end

M.format_on_save = function(bufnr)
	if vim.g.chat_formatting == nil then
		vim.g.chat_formatting = config.opts.auto_format
	end

	if not vim.g.chat_formatting then
		return
	end
    M.format_chat(bufnr)
end

M.format_chat = function(bufnr)
	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("normal! mg")
		local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local range_start = 2
		local in_code_block = false
		local in_list_item = false
		local format_sections = {} -- inclusive, 1 indexed

		for i, line in ipairs(buf_lines) do
			-- skip delimiter lines
			for _, delimiter in pairs(config.opts.delimiters) do
				if line:match("^%s*" .. delimiter:gsub("[%^$()%.%*%+%-?[%]]", "%%%1")) then
					format_sections[#format_sections + 1] = { range_start, i - 1 }
					range_start = i + 1
					goto continue
				end
			end

			if line:match("^%s*```[^`]*$") then
				-- if not line:match("^%s*```") then
				-- 	fix_backticks[#fix_backticks + 1] = i
				-- end

				if not in_code_block then
					format_sections[#format_sections + 1] = { range_start, i - 1 }
				else
					range_start = i + 1
				end
				in_code_block = not in_code_block

			-- always skip lines in a code block
			elseif in_code_block then
				range_start = i + 1

			-- handle list items
			elseif line:match("^%s*%d+%. ") or line:match("^%s*- ") or line:match("^%s*%* ") then
				format_sections[#format_sections + 1] = { range_start, i - 1 }
				range_start = i
				in_list_item = true
			elseif in_list_item and line == "" then
				format_sections[#format_sections + 1] = { range_start, i - 1 }
				range_start = i
				in_list_item = false
			end
			::continue::
		end

		if range_start <= #buf_lines then
			format_sections[#format_sections + 1] = { range_start, #buf_lines }
		end

		-- format in reverse order so line numbers don't change
		for i = #format_sections, 1, -1 do
			if format_sections[i][1] > format_sections[i][2] then
				goto continue
			-- skip if its just 1 line and that line is blank
			elseif format_sections[i][1] == format_sections[i][2] and buf_lines[format_sections[i][1]] == "" then
				goto continue
			end

			local section = format_sections[i]
			local s_line, e_line = section[1], section[2]
			vim.cmd("normal " .. s_line .. "GV" .. e_line .. "Ggq")
			::continue::
		end

		require("conform").format()

		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("normal! `g")
		end)
	end)
end

return M
