local config = require("chat.config")
local api = require("chat.api")

local M = {}

M.setup_buffer = function(bufnr)
	local key_opts = { noremap = true, silent = true, nowait = true, buffer = bufnr }
	vim.keymap.set("n", config.opts.keymap.send_message, M.send_message, key_opts)

	local opts = { buf = bufnr }
	vim.api.nvim_set_option_value("textwidth", vim.api.nvim_win_get_width(0) - 10, opts)

	if config.opts.wrap then
		vim.keymap.set("n", "j", "gj", key_opts)
		vim.keymap.set("n", "k", "gk", key_opts)
		vim.keymap.set("n", "^", "g^", key_opts)
		vim.keymap.set("n", "$", "g$", key_opts)
		vim.api.nvim_set_option_value("wrap", true, opts)
		vim.api.nvim_set_option_value("linebreak", true, opts)
	elseif config.opts.auto_format then
		vim.api.nvim_set_option_value("formatoptions", "t", opts)
	end

	if config.opts.scroll_on_focus then
		vim.cmd("normal! G")
	end
end

M.create_new_chat = function(selection, ft)
	for _, file in ipairs(vim.fn.readdir(config.opts.dir)) do
		local path = string.format("%s/%s", config.opts.dir, file)
		local lines = vim.fn.readfile(path)
		if lines[1] == config.opts.default.title then
			vim.cmd("edit " .. path)
			return vim.api.nvim_get_current_buf()
		end
	end

	local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
	local filename = string.format("%s/%s.chat", config.opts.dir, timestamp)

	vim.cmd("edit " .. filename)
	local bufnr = vim.api.nvim_get_current_buf()

	local lines = {
		config.opts.default.title,
		"",
		config.opts.delimiters.settings,
		"",
		config.opts.delimiters.model .. config.opts.default.model,
		"",
		config.opts.delimiters.temp .. config.opts.default.temp,
		"",
		config.opts.delimiters.system,
		"",
		config.opts.default.system_message,
		"",
		config.opts.delimiters.chat,
		"",
		config.opts.delimiters.user,
		"",
		"",
	}

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	if selection and #selection > 0 then
		-- add triple backticks to selection with filetype (markdown code)
		selection = "```" .. ft .. "\n" .. selection .. "```"
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, vim.split(selection, "\n"))
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("normal! G")
		end)
	end

	vim.cmd("write")

	return bufnr
end

M.load_last_chat = function(selection, ft)
	local latest_file = nil
	local latest_time = 0
	for _, file in ipairs(vim.fn.readdir(config.opts.dir)) do
		local path = string.format("%s/%s", config.opts.dir, file)
		local info = vim.loop.fs_stat(path)
		if info and info.type == "file" and info.mtime.sec > latest_time then
			latest_file = path
			latest_time = info.mtime.sec
		end
	end

	if latest_file then
		vim.cmd("edit " .. latest_file)
	else
		vim.api.nvim_err_writeln("No existing chat files found in " .. config.opts.dir)
	end
	local bufnr = vim.api.nvim_get_current_buf()

	if selection and #selection > 0 then
		-- add triple backticks to selection with filetype (markdown code)
		selection = "```" .. ft .. "\n" .. selection .. "```"
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, vim.split(selection, "\n"))
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("normal! G")
		end)
	end

	return bufnr
end

M.open = function(popup)
	if popup then
		local popup_win = require("chat.popup")
		if not popup_win.is_open() then
			popup_win.open()
		end
		if not popup_win.is_focused() then
			popup_win.focus()
		end
	end

	local function call_telescope()
		local previewers = require("telescope.previewers")
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		local custom_previewer = previewers.new_buffer_previewer({
			define_preview = function(self, entry, status)
				local path = entry.path or entry.filename
				vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "markdown")
				vim.fn.jobstart({ "cat", path }, {
					stdout_buffered = true,
					on_stdout = function(_, data)
						if data then
							vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, data)
						end
					end,
				})
			end,
		})

		local entry_maker = function(line)
			local entry = require("telescope.make_entry").gen_from_vimgrep()(line)
			if entry.value:match("1:1") then
				local filename, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
				entry.filename = filename
				entry.lnum = tonumber(lnum)
				entry.col = tonumber(col)
				entry.text = text
				entry.path = require("plenary.path"):new(config.opts.dir, filename):absolute()
				entry.time = vim.loop.fs_stat(entry.path).mtime.sec
				local timestamp = os.date("%d-%m-%Y", entry.time)
				entry.display = string.format("%s (%s)", entry.text:sub(3), timestamp)
				entry.ordinal = entry.display
				return entry
			end
			return nil
		end

		require("telescope.builtin").grep_string({
			prompt_title = "Load Conversation",
			search = "^# ",
			use_regex = true,
			cwd = config.opts.dir,
			entry_maker = entry_maker,
			previewer = custom_previewer,
			attach_mappings = function(prompt_bufnr, map)
				local function delete_file()
					local entry = action_state.get_selected_entry()
					local filepath = entry.path
					vim.cmd("silent !rm " .. filepath)
					actions.close(prompt_bufnr)
					vim.schedule(function()
						call_telescope()
					end)
				end

				map("i", config.opts.keymap.delete_chat, function()
					delete_file()
				end)
				map("n", config.opts.keymap.delete_chat, function()
					delete_file()
				end)
				return true
			end,
		})
	end

	-- wait so the popup doesn't cover telescope
	vim.defer_fn(function()
		call_telescope()
	end, 100)
end

M.popup_open = function(selection, ft)
	local new = false
	if vim.fn.isdirectory(config.opts.dir) ~= 1 then
		vim.fn.mkdir(config.opts.dir, "p")
		new = true
	elseif vim.fn.empty(vim.fn.readdir(config.opts.dir)) == 1 then
		new = true
	end

	new = new or selection ~= ""

	local bufnr
	if new then
		bufnr = M.create_new_chat(selection, ft)
	else
		bufnr = M.load_last_chat(selection, ft)
	end
end

local function parse_messages(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local messages = {}
	local role = nil
	local content = {}
	local model = config.opts.default.model
	local temp = config.opts.default.temp

	local in_system = false
	local sys_message = {}

	local in_chat = false

	for _, line in ipairs(lines) do
		if not in_chat then
			if line:find("^" .. config.opts.delimiters.model) then
				model = line:sub(config.opts.delimiters.model:len() + 1)
			elseif line:find("^" .. config.opts.delimiters.temp) then
				temp = tonumber(line:sub(config.opts.delimiters.temp:len() + 1))
			else
				in_chat = line == config.opts.delimiters.chat

				if in_system and not in_chat and (#sys_message > 0 or line ~= "") then
					table.insert(sys_message, line)
				end

				if in_chat then
					if #sys_message > 0 then
						table.remove(sys_message, #sys_message) -- remove trailing blank line
						table.insert(messages, { role = "system", content = table.concat(sys_message, " \n ") })
					end
				else
					if line == config.opts.delimiters.system then
						in_system = true
					end
				end
			end
		else
			-- start user message
			if line:find("^" .. config.opts.delimiters.user) then
				if role then -- save previous (assistant) message
					-- remove any blank lines from the end of the content
					while #content > 0 and content[#content] == "" do
						table.remove(content, #content)
					end
					table.insert(messages, { role = role, content = table.concat(content, " \n ") })
				end
				role = "user"
				content = {}

			-- start assistant message
			elseif line:find("^" .. config.opts.delimiters.assistant) then
				if role then -- save previous (user) message
					-- remove any blank lines from the end of the content
					while #content > 0 and content[#content] == "" do
						table.remove(content, #content)
					end
					table.insert(messages, { role = role, content = table.concat(content, " \n ") })
				end
				role = "assistant"
				content = {}

			-- add line to current message content
			elseif role and (#content > 0 or line ~= "") then
				table.insert(content, line)
			end
		end
	end

	if role then -- messages are appended on role switch, so last gets left out
		while #content > 0 and content[#content] == "" do
			table.remove(content, #content)
		end
		table.insert(messages, { role = role, content = table.concat(content, "\n") })
	end

	return messages, model, temp
end

local function generate_title(_messages, bufnr)
	local messages = {
		_messages[2],
		{ role = "system", content = "Write a short (1-5 words) title for this conversation:" },
	}
	local on_complete = function(err, res)
		-- callback function for end of response
		if not res then
			return
		end
		if err then
			vim.api.nvim_err_writeln("Error generating conversation title: " .. err)
		else
			local title = res.choices[1].message.content
			vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "# " .. title })
		end
	end

	api.request(messages, config.opts.title_model, bufnr, on_complete)
end

M.send_message = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local messages, model, temp = parse_messages(bufnr)

	if messages[#messages].role == "user" and messages[#messages].content == "" then
		print("skipping empty user message")
		return
	end

	-- remove any blank lines from the end of the buffer
	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	while #buf_lines > 0 and buf_lines[#buf_lines] == "" do
		table.remove(buf_lines, #buf_lines)
	end
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, buf_lines)

	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "", config.opts.delimiters.assistant, "", "" })

	if buf_lines[1] == config.opts.default.title then
		print("Generating title...")
		generate_title(messages, bufnr)
	end

	local on_complete = function(err, _)
		if err then
			vim.api.nvim_err_writeln("Error streaming response: " .. err)
		end

		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "", config.opts.delimiters.user, "", "" })

		M.format_chat(bufnr)

		if config.opts.auto_scroll then
			vim.api.nvim_buf_call(bufnr, function()
				vim.cmd("normal! G")
			end)
		end
		vim.cmd("silent w!")
	end

	api.stream(messages, model, temp, bufnr, on_complete)
end

M.delete = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	vim.fn.delete(filename)
	M.load_last_chat()
end

M.format_chat = function(bufnr)
	if not config.opts.auto_format then
		return
	end

	vim.api.nvim_buf_call(bufnr, function()
		vim.cmd("normal! mg")
		local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local range_start = 2
		local in_code_block = false
		local in_list_item = false
		local format_sections = {} -- inclusive, 1 indexed
		local fix_backticks = {}

		for i, line in ipairs(buf_lines) do
			if line:match("```") then
				if not line:match("^%s*```") then
					-- print(i .. " need to fix backticks")
					fix_backticks[#fix_backticks + 1] = i
				end

				if not in_code_block then
					-- print(i .. " start of code block")
					format_sections[#format_sections + 1] = { range_start, i - 1 }
				else
					-- print(i .. " end of code block")
					range_start = i + 1
				end
				in_code_block = not in_code_block

			-- always skip lines in a code block
			elseif in_code_block then
				range_start = i + 1

			-- handle list items
			elseif line:match("^%s*%d+%. ") or line:match("^%s*- ") then
				-- print(i .. " list item")
				format_sections[#format_sections + 1] = { range_start, i - 1 }
				range_start = i
				in_list_item = true
			elseif in_list_item and line == "" then
				-- print(i .. " end of list item")
				format_sections[#format_sections + 1] = { range_start, i - 1 }
				range_start = i
				in_list_item = false
			end
		end

		if range_start <= #buf_lines then
			format_sections[#format_sections + 1] = { range_start, #buf_lines }
			-- else
			--     print("can't add end")
			--     print(range_start)
			--     print(#buf_lines)
		end
		-- P(format_sections)

		-- delete the backticks from that line, and insert them in a line below
		for _, line in ipairs(fix_backticks) do
			local line_content = buf_lines[line]
			local new_content = line_content:gsub("```", "")
			vim.api.nvim_buf_set_lines(bufnr, line - 1, line, false, { new_content })
			-- insert a new line below, with backticks. do not overwrite existing content make a new line
			vim.cmd("normal! " .. line .. "Go```")

			-- fix all the ranges after this line to account for the new line
			for _, section in ipairs(format_sections) do
				if section[1] >= line then
					section[1] = section[1] + 1
					section[2] = section[2] + 1
				end
			end
		end

		-- format in reverse order so line numbers don't change
		for i = #format_sections, 1, -1 do
			if format_sections[i][1] > format_sections[i][2] then
				-- print("skipping invalid range " .. format_sections[i][1] .. "-" .. format_sections[i][2])
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
			-- vim.cmd("normal! G")
			vim.cmd("normal! `g")
		end)
	end)
end

return M
