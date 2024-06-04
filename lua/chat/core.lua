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
	elseif config.opts.auto_gq then
		vim.api.nvim_set_option_value("formatoptions", "t", opts)
	end

	if config.opts.scroll_on_focus then
		vim.cmd("normal! G")
	end
end

M.create_new_chat = function(selection, ft)
	local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
	local filename = string.format("%s/%s.chat", config.opts.dir, timestamp)

	vim.cmd("edit " .. filename)
	local bufnr = vim.api.nvim_get_current_buf()

	local lines = {
		config.opts.default_title,
		"",
		config.opts.delimiters.settings,
		"",
		config.opts.delimiters.model .. config.opts.default_model,
		"",
		config.opts.delimiters.system,
		"",
		config.opts.default_system_message,
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
		local sorters = require("telescope.sorters")
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

		local timestamp_sorter = sorters.get_fzy_sorter()
		timestamp_sorter.compare = function(a, b)
			return a.value < b.value
		end

		local entry_maker = function(line)
			local entry = require("telescope.make_entry").gen_from_vimgrep()(line)
			if entry.value:match("1:1") then
				local filename, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
				entry.filename = filename
				entry.lnum = tonumber(lnum)
				entry.col = tonumber(col)
				entry.text = text
				entry.path = require("plenary.path"):new(config.opts.dir, filename):absolute()
				-- entry.display = string.format("%s:%s:%s:%s", entry.filename, entry.lnum, entry.col, entry.text)
				local timestamp = os.date("%Y-%m-%d %H:%M:%S", vim.loop.fs_stat(entry.path).mtime.sec)
				entry.display = string.format("%s (%s)", entry.text:sub(3), timestamp)
				entry.ordinal = entry.display
				return entry
			end
			return nil
		end

		require("telescope.builtin").grep_string({
			prompt_title = "Load Conversation",
			search = "^# ",
			sorters = timestamp_sorter,
			use_regex = true,
			cwd = config.opts.dir,
			sort_lastused = true,
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
	local model = config.opts.default_model

	local in_system = false
	local sys_message = {}

	local in_chat = false

	for _, line in ipairs(lines) do
		if not in_chat then
			if line:find("^" .. config.opts.delimiters.model) then
				model = line:sub(config.opts.delimiters.model:len() + 1)
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

	return messages, model
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
	local messages, model = parse_messages(bufnr)

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

	if buf_lines[1] == config.opts.default_title then
		print("Generating title...")
		generate_title(messages, bufnr)
	end

	local on_complete = function(err, _)
		if err then
			vim.api.nvim_err_writeln("Error streaming response: " .. err)
		end

		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "", config.opts.delimiters.user, "", "" })

		M.gq_chat(bufnr)

		if config.opts.auto_scroll then
			vim.api.nvim_buf_call(bufnr, function()
				vim.cmd("normal! G")
			end)
		end
		vim.cmd("silent w!")
	end

	api.stream(messages, model, bufnr, on_complete)
end

M.delete = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	vim.fn.delete(filename)
	M.load_last_chat()
end

M.gq_chat = function(bufnr)
	if not config.opts.auto_gq then
		return
	end

	vim.api.nvim_buf_call(bufnr, function()
		local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local start_line = 2
		local in_code_block = false
		local format_sections = {} -- inclusive, 1 indexed

		for i, line in ipairs(buf_lines) do
			if line:match("```") then
				if not in_code_block then
					format_sections[#format_sections + 1] = { start_line, i - 1 }
				else
					start_line = i + 1
				end
				in_code_block = not in_code_block
			end
		end

		-- catch text after the last code block
		if not in_code_block then
			format_sections[#format_sections + 1] = { start_line, #buf_lines }
		end

		-- P(format_sections)

		-- format in reverse order so line numbers don't change
		for i = #format_sections, 1, -1 do
			local section = format_sections[i]
			local s_line, e_line = section[1], section[2]
			vim.cmd("normal " .. s_line .. "GV" .. e_line .. "Ggq")
		end

		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("normal! G")
		end)
	end)
end

return M
