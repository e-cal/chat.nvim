local config = require("chat.config")
local api = require("chat.api")

local M = {}

local function setup_buffer(bufnr)
	local keymap_opts = { noremap = true, silent = true, nowait = true, buffer = bufnr }
	vim.keymap.set("n", "<CR>", M.send_message, keymap_opts)
	vim.keymap.set("n", "j", "gj", keymap_opts)
	vim.keymap.set("n", "k", "gk", keymap_opts)
	vim.keymap.set("n", "^", "g^", keymap_opts)
	vim.keymap.set("n", "$", "g$", keymap_opts)
	vim.cmd("normal! G")
end

M.create_new_chat = function()
	local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
	local filename = string.format("%s/%s.md", config.opts.dir, timestamp)
	local file = io.open(filename, "w")
	if file then
		file:write("# New Chat\n\n")
		file:write("### System Message\n")
		file:write(config.opts.system)
		file:write("\n\n---\n\n")
		file:write(config.opts.user_prefix .. "\n\n")
		file:close()
		vim.cmd("edit " .. filename)
	else
		vim.api.nvim_err_writeln("Failed to create new chat file: " .. filename)
	end
	local bufnr = vim.api.nvim_get_current_buf()
	setup_buffer(bufnr)
	return bufnr
end

M.load_last_chat = function()
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
	setup_buffer(bufnr)
	return bufnr
end

M.open = function()
	local ui = require("chat.ui")
	if not ui.is_open() then
		ui.open()
	end
	if not ui.is_focused() then
		ui.focus()
	end
	-- wait a sec
	vim.defer_fn(function()
		require("telescope.builtin").grep_string({
			prompt_title = "Load Conversation",
			search = "^# ",
			use_regex = true,
			cwd = config.opts.dir,
		})
		setup_buffer(vim.api.nvim_get_current_buf())
	end, 100)
end

M.popup_open = function()
	local new = false
	if vim.fn.isdirectory(config.opts.dir) ~= 1 then
		vim.fn.mkdir(config.opts.dir, "p")
		new = true
	elseif vim.fn.empty(vim.fn.readdir(config.opts.dir)) == 1 then
		new = true
	end

	local bufnr
	if new then
		bufnr = M.create_new_chat()
	else
		bufnr = M.load_last_chat()
	end
end

local function parse_messages(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local messages = {}
	local current_role = nil
	local current_content = {}

	for _, line in ipairs(lines) do
		if line:find("^"..config.opts.system_prefix) then
			current_role = "system"
			current_content = {}
		elseif line:find("^"..config.opts.user_prefix) then
			if current_role then
				table.insert(messages, { role = current_role, content = table.concat(current_content, "\n") })
			end
			current_role = "user"
			current_content = {}
		elseif line:find("^"..config.opts.assistant_prefix) then
			if current_role then
				table.insert(messages, { role = current_role, content = table.concat(current_content, "\n") })
			end
			current_role = "assistant"
			current_content = {}
		elseif current_role then
			table.insert(current_content, line)
		end
	end

	if current_role then
		table.insert(messages, { role = current_role, content = table.concat(current_content, "\n") })
	end

	return messages
end

local function generate_title(messages, bufnr)
	local _messages = {
		messages[2],
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

	api.request(_messages, bufnr, on_complete)
end

M.send_message = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local messages = parse_messages(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", config.opts.assistant_prefix, "" })

	if #messages == 2 and messages[1].role == "system" then
        print("generate_title")
		generate_title(messages, bufnr)
    else
        P(messages)
	end

	local on_complete = function(err, _)
		if err then
			vim.api.nvim_err_writeln("Error streaming response: " .. err)
		end
		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", config.opts.user_prefix, "" })
		if config.opts.auto_scroll then
			vim.cmd("normal! G")
		end
		if config.opts.auto_save then
			vim.cmd("silent w!")
		end
	end

	api.stream(messages, bufnr, on_complete)
end

M.delete = function()
	local ui = require("chat.ui")
    -- if not open and focused, return
    if not ui.is_open() or not ui.is_focused() then
        print("Chat is not open or focused")
        return
    end
	local bufnr = vim.api.nvim_get_current_buf()
	local filename = vim.api.nvim_buf_get_name(bufnr)
	vim.api.nvim_buf_delete(bufnr, { force = true })
	vim.fn.delete(filename)
end

return M
