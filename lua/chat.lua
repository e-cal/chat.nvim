local config = require("chat.config")
local ui = require("chat.ui")
local api = require("chat.api")
local chat = require("chat.core")

local M = {}

M.setup = function(opts)
    config.setup(opts)
end

M.focus = function(size, direction)
    ui.open(size, direction)
end

M.close = function()
    if ui.is_open() then
        ui.close()
    end
end

M.toggle = function(size, direction)
    ui.toggle(size, direction)
end

M.new_chat = function()
    chat.create_new_chat()
end

M.open = function()
    chat.open()
end

M.delete = function()
    chat.delete()
end

-- M.set_model = function(model)
--     config.opts.openai_model = model
--     config.opts.anthropic_model = model
--     if M.popup then
--         M.popup.border.text.bottom = " Model: " .. model .. " "
--         M.popup:update()
--     end
-- end
--
-- M.set_provider = function(provider)
--     api.set_provider(provider)
-- end

return M
