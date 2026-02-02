local config = require("chat.config")

local M = {}

M.create_new_chat = function(selection, ft)
	if vim.fn.isdirectory(config.opts.dir) ~= 1 then
		vim.fn.mkdir(config.opts.dir, "p")
	end
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
		'<!--' .. config.opts.delimiters.reasoning .. 'medium -->',
		"",
		config.opts.delimiters.system,
		"",
		config.opts.default.system_message:gsub("\n", " "),
		"",
		config.opts.delimiters.chat,
		"",
		config.opts.delimiters.user,
		"",
		"",
	}

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	if selection and #selection > 0 then
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
	if vim.fn.isdirectory(config.opts.dir) ~= 1 then
		vim.api.nvim_err_writeln("No existing chat files found in " .. config.opts.dir)
		return nil
	end
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
		selection = "```" .. ft .. "\n" .. selection .. "```"
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, vim.split(selection, "\n"))
		vim.api.nvim_buf_call(bufnr, function()
			vim.cmd("normal! G")
		end)
	end

	return bufnr
end

M.delete = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	vim.fn.delete(filename)
	M.load_last_chat()
end

M.open_chat = function(filename, popup)
	if popup then
		local popup_win = require("chat.popup")
		if not popup_win.is_open() then
			popup_win.open()
		end
		if not popup_win.is_focused() then
			popup_win.focus()
		end
	end

	if filename and filename ~= "" then
		vim.cmd("edit " .. config.opts.dir .. "/" .. filename)
		return
	end

	local function call_telescope()
		local previewers = require("telescope.previewers")
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		local custom_previewer = previewers.new_buffer_previewer({
			define_preview = function(self, entry, _)
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
			if entry.value:match(":1:1") then
				local entry_filename, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
				entry.filename = entry_filename
				entry.lnum = tonumber(lnum)
				entry.col = tonumber(col)
				entry.text = text
				entry.path = require("plenary.path"):new(config.opts.dir, entry_filename):absolute()
				entry.time = vim.loop.fs_stat(entry.path).mtime.sec
				local timestamp = os.date("%b %d %Y", entry.time)
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

	local function call_fzf()
		if not vim.fn.exists("*fzf#run") == 1 then
			vim.notify(
				"FZF-Vim is not installed. Please install it or set config.opts.finder = 'telescope'.",
				vim.log.levels.ERROR
			)
			return
		end

		if vim.fn.isdirectory(config.opts.dir) ~= 1 then
			vim.notify("No existing chat files found in " .. config.opts.dir, vim.log.levels.INFO)
			return
		end

		local preview_cmd = ""
		if vim.fn.executable("bat") == 1 then
			preview_cmd = "bat --style=numbers --color=always --line-range :500 --language=markdown {2}"
		elseif vim.fn.executable("cat") == 1 then
			preview_cmd = "cat {2}"
		end

		local chat_entries = {}

		for _, file in ipairs(vim.fn.readdir(config.opts.dir)) do
			if file:match("%.chat$") then
				local path = string.format("%s/%s", config.opts.dir, file)
				local lines = vim.fn.readfile(path, "", 1)
				if #lines > 0 and lines[1]:match("^# ") then
					local title = lines[1]:sub(3)
					local stat = vim.loop.fs_stat(path)
					local timestamp = os.date("%d-%m-%Y", stat.mtime.sec)
					local display = string.format("%s (%s)", title, timestamp)

					table.insert(chat_entries, {
						display = display,
						path = path,
						timestamp = stat.mtime.sec,
					})
				end
			end
		end

		table.sort(chat_entries, function(a, b)
			return a.timestamp > b.timestamp
		end)

		local display_entries = {}
		local path_map = {}
		for _, entry in ipairs(chat_entries) do
			table.insert(display_entries, entry.display .. "\t" .. entry.path)
			path_map[entry.display] = entry.path
		end

		local options = {
			source = display_entries,
			options = {
				"--prompt",
				"Load Conversation> ",
				"--bind",
				"esc:abort",
				"--delimiter",
				"\t",
				"--with-nth",
				"1",
			},
			sink = function(selected)
				if selected then
					local path = path_map[selected]
					if path then
						vim.cmd("edit " .. path)
					end
				end
			end,
		}

		if preview_cmd ~= "" then
			table.insert(options.options, "--preview")
			table.insert(options.options, preview_cmd)
			table.insert(options.options, "--preview-window")
			table.insert(options.options, "right:60%")
		end

		vim.fn["fzf#run"](vim.fn["fzf#wrap"](options))
	end

	-- wait so the popup doesn't cover finder
	vim.defer_fn(function()
		if config.opts.finder == "fzf" then
			call_fzf()
		else
			call_telescope()
		end
	end, 100)
end

return M
