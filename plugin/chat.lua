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
	local args = vim.split(opts.args, " ")
	local popup = false
	for _, arg in ipairs(args) do
		if arg == "popup" then
			popup = true
			break
		end
	end
	require("chat").open(popup)
end, {
	nargs = "?",
	complete = function()
		return { "popup" }
	end,
})

cmd("ChatDelete", function()
	require("chat").delete()
end, {})

cmd("ChatResize", function(opts)
	local size = tonumber(opts.args)
	require("chat").resize(size)
end, { nargs = 1 })

cmd("ChatInline", function(opts)
	local replace = opts.args == "replace"
	local context
	if vim.fn.mode():match("[vV]") then
		vim.cmd('silent normal! "vy')
		context = vim.fn.getreg("v")

		-- only allow replacing with a visual selection
		if replace then
			vim.cmd("normal! gv")
			vim.cmd('normal! "_d')
		else
			vim.cmd("normal! `>")
			vim.cmd("normal! o")
		end
	else
		-- send the whole file up to the cursor line
		context = vim.api.nvim_buf_get_lines(0, 0, vim.fn.line("."), true)
        context = table.concat(context, "\n")
		vim.cmd("normal! o")
	end

	if not replace then
        context = "```" .. vim.bo.filetype .. "\n" .. context .. "\n```"
	end

	require("chat").inline(context)
end, {
	nargs = "?",
	complete = function()
		return { "replace" }
	end,
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
