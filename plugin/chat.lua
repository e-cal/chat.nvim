local config = require("chat.config")

-------------------------------------------------------------------------------
--                               User Commands                               --
-------------------------------------------------------------------------------
local cmd = vim.api.nvim_create_user_command

cmd("ChatFocus", function(opts)
	-- opts.args is all the arguments together in a string
	-- need to split it by space
	-- if there's a dir {top, bottom, left, right}, make that dir
	-- if there's a number, make that size
	local size = nil
	local direction = nil
	local args = vim.split(opts.args, " ")
	for _, arg in ipairs(args) do
		if tonumber(arg) then
			size = tonumber(arg)
		else
			direction = arg
		end
	end
	require("chat").focus(size, direction)
end, {
	nargs = "?",
	complete = function()
		return { "top", "bottom", "left", "right", "center" }
	end,
})

cmd("ChatClose", function()
	require("chat").close()
end, {})

cmd("ChatToggle", function(opts)
	local size = nil
	local direction = nil
	local args = vim.split(opts.args, " ")
	for _, arg in ipairs(args) do
		if tonumber(arg) then
			size = tonumber(arg)
		else
			direction = arg
		end
	end
	require("chat").toggle(size, direction)
end, {
	nargs = "?",
	complete = function()
		return { "top", "bottom", "left", "right", "center" }
	end,
})

cmd("ChatNew", function()
	require("chat").new_chat()
end, {})

cmd("ChatOpen", function(opts)
	local filename = opts.args ~= "" and opts.args or nil
	require("chat").open(filename)
end, {
	nargs = "?",
    -- TODO: get the list of chat files using config for path
	-- complete = function()
	-- 	return vim.fn.readdir()
	-- end,
})

cmd("ChatDelete", function()
	require("chat").delete()
end, {})

cmd("ChatResize", function(opts)
	local size = tonumber(opts.args)
	require("chat").resize(size)
end, { nargs = 1 })

cmd("ChatInline", function(opts)
	local context
	if vim.fn.mode():match("[vV]") then
		vim.cmd('silent normal! "vy')
		context = vim.fn.getreg("v")
        vim.cmd("normal! `>")
        vim.cmd("normal! o")
	else
		-- send the whole file up to the cursor line
		context = vim.api.nvim_buf_get_lines(0, 0, vim.fn.line("."), true)
		context = table.concat(context, "\n")
	end

	local model = "default"
    if opts.args and opts.args ~= "" then
        model = opts.args
    end

	require("chat").inline(context, model)
end, {
	nargs = "?",
})

cmd("ChatReplace", function(opts)
	local context
	if vim.fn.mode():match("[vV]") then
		vim.cmd('silent normal! "vy')
		context = vim.fn.getreg("v")
        vim.cmd("normal! gv")
        vim.cmd('normal! "_d')
	else
        print("not in visual mode")
        return
	end

	local model = "default"
    if opts.args and opts.args ~= "" then
        model = opts.args
    end

	require("chat").replace(context, model)
end, {
	nargs = 1,
})

cmd("ChatSetupBuffer", function()
	require("chat").setup_buffer()
end, {})

cmd("ChatStop", function()
	require("chat").stop()
end, {})

cmd("ChatToggleFormatting", function()
	require("chat").toggle_formatting()
end, {})

-------------------------------------------------------------------------------
--                               Auto Commands                               --
-------------------------------------------------------------------------------

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

local chat_group = augroup("_chat_nvim", { clear = true })

autocmd({ "BufNewFile", "BufRead" }, {
	group = chat_group,
	pattern = "*.chat",
	command = "set filetype=markdown",
})

autocmd("BufEnter", {
	group = chat_group,
	pattern = "*.chat",
	callback = function()
		require("chat.core").setup_buffer(vim.api.nvim_get_current_buf())
	end,
})

autocmd("BufLeave", {
	group = chat_group,
	pattern = "*.chat",
	command = "silent! write!",
})

autocmd("BufWritePre", {
	group = chat_group,
	pattern = "*.chat",
	callback = function()
		require("chat.core").format_chat(vim.api.nvim_get_current_buf())
	end,
})

autocmd("VimResized", {
	group = chat_group,
	pattern = "*.chat",
    callback = function()
    vim.opt.textwidth = math.floor(vim.api.nvim_win_get_width(0) - 10)
    end,
})
