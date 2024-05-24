local cmd = vim.api.nvim_create_user_command

local get_direction_options = function()
	return { "top", "bottom", "left", "right", "center" }
end

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
		return get_direction_options()
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
		return get_direction_options()
	end,
})

cmd("ChatNew", function()
	require("chat").new_chat()
end, {})

cmd("ChatOpen", function()
	require("chat").open()
end, {})

cmd("ChatDelete", function()
	require("chat").delete()
end, {})

cmd("ChatResize", function(opts)
	local size = tonumber(opts.args)
	require("chat").resize(size)
end, { nargs = 1 })

vim.cmd([[ 
  augroup CHAT_GROUP
    autocmd!
    autocmd BufNewFile,BufRead *.chat set filetype=markdown
    autocmd BufEnter *.chat lua require('chat.core').setup_buffer(vim.api.nvim_get_current_buf())
    autocmd BufLeave *.chat silent! write!
  augroup END
]])
