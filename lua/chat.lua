local config = require("chat.config")
local popup = require("chat.popup")
local api = require("chat.api")
local chat = require("chat.core")

local M = {}

M.setup = function(opts)
	config.setup(opts)
end

M.focus = function(size, direction)
	popup.open(size, direction)
end

M.close = function()
	if popup.is_open() then
		popup.close()
	end
end

M.toggle = function(size, direction)
	popup.toggle(size, direction)
end

M.new_chat = function()
	chat.create_new_chat()
end

M.open = function(as_popup)
	chat.open(as_popup)
end

M.delete = function()
	chat.delete()
end

return M
