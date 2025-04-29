local config = require("chat.config")
local popup = require("chat.popup")
local core = require("chat.core")
local chat = require("chat.chat")
local buffer = require("chat.buffer")
local actions = require("chat.actions")

local M = {}

function M.setup(opts)
	config.setup(opts)
end

function M.setup_buffer()
	buffer.setup_buffer(vim.api.nvim_get_current_buf())
end

function M.focus(size, direction)
	popup.open(size, direction)
end

function M.close()
	if popup.is_open() then
		popup.close()
	end
end

function M.toggle(size, direction)
	popup.toggle(size, direction)
    vim.notify("Toggle chat window")
end

function M.new_chat()
	chat.create_new_chat()
end

function M.open(filename)
	chat.open_chat(filename, false)
end

function M.delete()
	chat.delete()
end

function M.inline(context, model)
	actions.inline(context, model)
end

function M.format(bufnr)
	actions.format_chat(bufnr)
end

function M.format_on_save(bufnr)
	actions.format_on_save(bufnr)
end

function M.toggle_formatting()
	if vim.g.chat_formatting then
		vim.g.chat_formatting = false
        vim.notify("Disabled auto formatting")
	else
		vim.g.chat_formatting = true
        vim.notify("Enabled auto formatting")
	end
end

function M.stop()
	core.stop_generation()
end

function M.resize(size)
	popup.resize(size)
end

function M.replace(context, model)
	core.inline(context, model)
end

return M
