local config = require("chat.config")
local api = require("chat.api")

local M = {}
M.wrap_keymaps_active = M.wrap_keymaps_active or {}

M.setup_buffer = function(bufnr)
	local key_opts = { noremap = true, silent = true, nowait = true, buffer = bufnr }

	-- keymaps
	vim.keymap.set("n", config.opts.keymap.send_message, M.send_message, key_opts)
	vim.keymap.set("n", config.opts.keymap.yank_code, M.yank_code, key_opts)
	vim.keymap.set("n", config.opts.keymap.stop_generation, M.stop_generation, key_opts)

	-- global
	if config.opts.keymap.paste_code ~= "" then
		vim.keymap.set(
			"n",
			config.opts.keymap.paste_code,
			'"' .. config.opts.code_register .. "p",
			{ noremap = true, nowait = true }
		)
		vim.keymap.set(
			"v",
			config.opts.keymap.paste_code,
			'"' .. config.opts.code_register .. "p",
			{ noremap = true, nowait = true }
		)
	end

	local opts = { buf = bufnr }
	vim.api.nvim_set_option_value("textwidth", vim.api.nvim_win_get_width(0) - 10, opts)

	if config.opts.wrap then
		-- vim.keymap.set("n", "j", "gj", key_opts)
		-- vim.keymap.set("n", "k", "gk", key_opts)
		-- vim.keymap.set("n", "^", "g^", key_opts)
		-- vim.keymap.set("n", "$", "g$", key_opts)
		vim.api.nvim_set_option_value("wrap", true, { win = 0 })
		vim.api.nvim_set_option_value("linebreak", true, { win = 0 })
        M.wrap_keymaps_active[bufnr] = false
        M.update_wrap(bufnr)
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
				"--prompt", "Load Conversation> ",
				"--bind", "esc:abort",
				"--delimiter", "\t",
				"--with-nth", "1",
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

M.popup_open = function(selection, ft)
	local new = false
	if vim.fn.isdirectory(config.opts.dir) ~= 1 then
		vim.fn.mkdir(config.opts.dir, "p")
		new = true
	elseif vim.fn.empty(vim.fn.readdir(config.opts.dir)) == 1 then
		new = true
	end

	new = new or selection ~= ""

	if new then
		M.create_new_chat(selection, ft)
	else
		M.load_last_chat(selection, ft)
	end
end


M.update_wrap = function(bufnr)
  if not config.opts.wrap then
    return
  end

  local node = vim.treesitter.get_node()
  if not node then
    vim.api.nvim_set_option_value("wrap", true, { win = 0 })
    if not M.wrap_keymaps_active[bufnr] then
      local key_opts = { noremap = true, silent = true, nowait = true, buffer = bufnr }
      vim.keymap.set("n", "j", "gj", key_opts)
      vim.keymap.set("n", "k", "gk", key_opts)
      vim.keymap.set("n", "^", "g^", key_opts)
      vim.keymap.set("n", "$", "g$", key_opts)
      M.wrap_keymaps_active[bufnr] = true
    end
    return
  end

  -- Traverse up the node tree to check if we're inside a fenced code block
  while node and node:type() ~= "fenced_code_block" do
    node = node:parent()
  end

  local key_opts = { noremap = true, silent = true, nowait = true, buffer = bufnr }

  if node and node:type() == "fenced_code_block" then
    -- Inside a code block, disable wrap
    vim.api.nvim_set_option_value("wrap", false, { win = 0 })
    -- Only delete keymaps if they are active
    if M.wrap_keymaps_active[bufnr] then
      -- Use pcall to avoid errors if mappings don't exist
      pcall(vim.keymap.del, "n", "j", { buffer = bufnr })
      pcall(vim.keymap.del, "n", "k", { buffer = bufnr })
      pcall(vim.keymap.del, "n", "^", { buffer = bufnr })
      pcall(vim.keymap.del, "n", "$", { buffer = bufnr })
      M.wrap_keymaps_active[bufnr] = false
    end
  else
    -- Outside a code block, enable wrap
    vim.api.nvim_set_option_value("wrap", true, { win = 0 })
    -- Only set keymaps if they are not active
    if not M.wrap_keymaps_active[bufnr] then
      vim.keymap.set("n", "j", "gj", key_opts)
      vim.keymap.set("n", "k", "gk", key_opts)
      vim.keymap.set("n", "^", "g^", key_opts)
      vim.keymap.set("n", "$", "g$", key_opts)
      M.wrap_keymaps_active[bufnr] = true
    end
  end
end

local function parse_messages(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local messages = {}
	local role = nil
	local content = {}
	local model = config.opts.default.model
	local temp = nil
	local save_path = nil

	local in_system = false
	local sys_message = {}

	local in_chat = false

	for _, line in ipairs(lines) do
		if not in_chat then
			if line:find("^" .. config.opts.delimiters.model) then
				model = line:sub(config.opts.delimiters.model:len() + 1)
			elseif line:find("^" .. config.opts.delimiters.temp) then
				temp = tonumber(line:sub(config.opts.delimiters.temp:len() + 1))
			elseif line:find("^" .. config.opts.delimiters.entropix_save_path) then
				-- make it substitute "./" with the current directory
				save_path = line:sub(config.opts.delimiters.entropix_save_path:len() + 1)

				-- Get the current directory
				local current_dir = vim.fn.getcwd()

				-- Substitute "./" with the current directory
				save_path = save_path:gsub("^%./", current_dir .. "/")
			else
				in_chat = line == config.opts.delimiters.chat

				if in_system and not in_chat and (#sys_message > 0 or line ~= "") then
					if line:find("^" .. config.opts.delimiters.file) then
						local filename = line:sub(config.opts.delimiters.file:len() + 1)
						print("[chat.nvim] inserting file: " .. filename)
						local file = io.open(filename, "r")
						if not file then
							print("[chat.nvim] error opening file: " .. filename)
						else
							local file_content = file:read("*a")
							local file_extension = filename:match("%.([^%.]+)$") or ""
							file:close()
							table.insert(sys_message, filename)
							table.insert(sys_message, "```" .. file_extension)
							for file_line in file_content:gmatch("[^\r\n]+") do
								table.insert(sys_message, file_line)
							end
							table.insert(sys_message, "```")
						end
					else
						table.insert(sys_message, line)
					end
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
		else -- in chat
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
				if line:find("^" .. config.opts.delimiters.file) then -- insert file
					local filename = line:sub(config.opts.delimiters.file:len() + 1)
					print("[chat.nvim] inserting file: " .. filename)
					-- insert the contents of the file
					local file = io.open(filename, "r")
					if not file then
						print("[chat.nvim] error opening file: " .. filename)
					else
						local file_content = file:read("*a")
						local file_extension = filename:match("%.([^%.]+)$") or ""
						file:close()
						table.insert(content, filename)
						table.insert(content, "```" .. file_extension)
						for file_line in file_content:gmatch("[^\r\n]+") do
							table.insert(content, file_line)
						end
						table.insert(content, "```")
					end
				else -- normal line
					table.insert(content, line)
				end
			end
		end
	end

	if role then -- messages are appended on role switch, so last gets left out (catch it here)
		while #content > 0 and content[#content] == "" do
			table.remove(content, #content)
		end
		table.insert(messages, { role = role, content = table.concat(content, "\n") })
	end

	-- P(messages)

	return messages, model, temp, save_path
end

local function generate_title(_messages, bufnr)
	local messages = {
		{ role = "system", content = "Your task is to summarize the conversation into a title" },
		_messages[2],
		{
			role = "user",
			content = "Write a short (1-5 words) title for this conversation based on the previous message. Only write the title, do not respond to the query.",
		},
	}

	local on_complete = function(err, res)
		if err then
			vim.api.nvim_err_writeln("[chat.nvim] Error generating conversation title: " .. err)
		elseif not res then
			return
		else
			local title = res.choices[1].message.content
			print("[chat.nvim] Generated title: " .. title)
			vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "# " .. title })
		end
	end

	api.request({
		messages = messages,
		model = config.opts.title_model,
		temp = 0.8,
		bufnr = bufnr,
		on_complete = on_complete,
	})
end

M.send_message = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local messages, model, temp, save_path = parse_messages(bufnr)

	if messages[#messages].role == "user" and messages[#messages].content == "" then
		print("[chat.nvim] Skipping empty user message")
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
		print("[chat.nvim] Generating title...")
		generate_title(messages, bufnr)
	end

	local on_complete = function(err, _)
		if err then
			vim.api.nvim_err_writeln("[chat.nvim] Error streaming response: " .. err)
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

	api.request({
		messages = messages,
		model = model,
		temp = temp,
		save_path = save_path,
		bufnr = bufnr,
		on_complete = on_complete,
		stream_response = true,
	})
end

M.delete = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	vim.fn.delete(filename)
	M.load_last_chat()
end

M.format_chat = function(bufnr)
	if vim.g.chat_formatting == nil then
		vim.g.chat_formatting = config.opts.auto_format
	end

	if not vim.g.chat_formatting then
		return
	end

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

M.inline = function(context, _model)
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	local messages = {
		{ role = "system", content = config.opts.inline.system_message },
		{ role = "user", content = context },
	}
	-- P(messages)

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
				if chunk_data.choices ~= nil then -- openai-style api
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

M.stop_generation = function()
	vim.g.chat_stop_generation = true
	print("[chat.nvim] Stopping generation")
end

return M
