local Popup = require("nui.popup")
local config = require("chat.config")
local chat = require("chat.chat")

local M = {}

M.popup = nil

M.is_open = function()
	return M.popup ~= nil
end

M.close = function()
	if M.popup then
		M.popup:unmount()
	end
	M.popup = nil
end

M.toggle = function(size, direction)
	if M.is_open() then
		M.close()
	else
		M.open(size, direction)
	end
end

M.focus = function()
	vim.api.nvim_set_current_win(M.popup.winid)
end

M.is_focused = function()
	return vim.api.nvim_get_current_win() == M.popup.winid
end

M.open = function(size, direction)
	if M.is_open() then
		if M.is_focused() then
			vim.cmd("wincmd p")
		else
			M.focus()
		end
		return
	end

	local opts = config.opts.ui

	-- Set default size and direction if not provided
	size = size or opts.size
	if direction == nil or direction == "" then
		direction = opts.direction
	end

	-- Parse size and direction
	local width, height = "96%", "96%"
	if direction == "top" or direction == "bottom" then
		height = (type(size) == "number" and size .. "%")
			or (type(size) == "string" and string.match(size, "(%d+)%%"))
			or "30%"
	elseif direction == "left" or direction == "right" then
		width = (type(size) == "number" and size .. "%")
			or (type(size) == "string" and string.match(size, "(%d+)%%"))
			or opts.width
	elseif direction == "center" then
		width = (type(size) == "number" and size .. "%")
			or (type(size) == "string" and string.match(size, "(%d+)%%"))
			or "50%"
		height = width
	end
	local row, col = "1", "50%"

	if direction == "top" then
		row = "0"
	elseif direction == "bottom" then
		row = "100%"
	elseif direction == "left" then
		col = "0"
	elseif direction == "right" then
		col = "100%"
	elseif direction == "center" then
		row = "50%"
		col = "50%"
	end

	M.popup = Popup({
		enter = true,
		focusable = true,
		border = {
			style = "rounded",
			text = {
				top = " Chat ",
				top_align = "center",
                -- todo
				-- bottom = " Model: " .. config.opts.default_provider .. " ",
				-- bottom_align = "left",
			},
		},
		position = {
			row = row,
			col = col,
		},
		size = {
			width = width or opts.width,
			height = height or opts.height,
		},
		buf_options = {
			modifiable = true,
			filetype = "markdown",
		},
		win_options = {
			wrap = opts.wrap,
		},
	})

	M.popup:mount()

	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(M.popup.winid),
		callback = function()
			M.close()
		end,
	})

	chat.popup_open()
end

M.resize = function(size)
	if M.is_open() then
		M.close()
		M.open(size)
	end
end

return M
