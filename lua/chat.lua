local config = require("chat.config")
local popup = require("chat.popup")
local chat = require("chat.core")

local M = {}

M.setup = function(opts)
	config.setup(opts)
end

M.setup_buffer = function()
	chat.setup_buffer(vim.api.nvim_get_current_buf())
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

M.open = function(filename)
	chat.open_chat(filename, false)
end

M.delete = function()
	chat.delete()
end

M.inline = function(context, model)
	chat.inline(context, model)
end

M.toggle_formatting = function()
    if vim.g.chat_formatting then
        vim.g.chat_formatting = false
        print("[chat.nvim] Disabling formatting")
    else
        vim.g.chat_formatting = true
        print("[chat.nvim] Enabling formatting")
    end
end

M.stop = function()
    chat.stop_generation()
end

return M
