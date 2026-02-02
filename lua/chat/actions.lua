local config = require("chat.config")
local api = require("chat.api")

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
				vim.notify("yanked code")
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

M.complete_inline = function(context, _model)
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	local messages = {
		{ role = "system", content = config.opts.inline.system_message },
		{ role = "user", content = context },
	}
	-- P(messages)

    local reasoning_start = false
	local on_chunk = function(err, chunk)
		if err then
			vim.api.nvim_err_writeln("Error streaming response: " .. err)
			return
		end
		if chunk then
			for chunk_json in chunk:gmatch("[^\n]+") do
				local raw_json = string.gsub(chunk_json, "^data: ", "")
				local ok, chunk_data = pcall(vim.json.decode, raw_json)
				if not ok then
					goto continue
				end

				-- print("on_chunk")
				-- P(chunk_data)

				local chunk_content
				if chunk_data.choices ~= nil and chunk_data.choices[1] ~= nil then -- openai-style api
					if chunk_data.choices[1].delta ~= nil then
						chunk_content = chunk_data.choices[1].delta.content
					else -- base model
						chunk_content = chunk_data.choices[1].text
					end
				elseif chunk_data.type == "content_block_delta" then -- anthropic api
					chunk_content = chunk_data.delta.text
				end
				if chunk_content == nil then
					goto continue
				end

				local lines = vim.split(chunk_content, "\n")
				for i, line in ipairs(lines) do
					if i == 1 then
						local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
						local new_line = current_line:sub(1, col) .. line .. current_line:sub(col + 1)
						vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
						col = col + #line
					else
						row = row + 1
						vim.api.nvim_buf_set_lines(bufnr, row, row, false, { line })
						col = #line
					end
				end
				vim.api.nvim_win_set_cursor(0, { row + 1, col })

				::continue::
			end
		end
	end

	local on_complete = function(err, _)
		if err then
			vim.api.nvim_err_writeln("Error completing inline response: " .. err)
		end
	end

	local model
	if _model == "default" then
		model = config.opts.inline.instruct_model
	elseif _model == "base" then
		model = config.opts.inline.base_model
	else
		model = _model
	end

	api.request({
		messages = messages,
		model = model,
		temp = config.opts.inline.temp,
		bufnr = bufnr,
		on_complete = on_complete,
		stream_response = true,
		on_chunk = on_chunk,
	})
end

return M
