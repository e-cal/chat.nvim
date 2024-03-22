local config = require("chat.config")
local ui = require("chat.ui")

local M = {}

M.setup = function(opts)
    config.setup(opts)
end

M.toggle = function(size, direction)
    if ui.is_open() then
        ui.close()
    else
        ui.open(size, direction)
    end
end

M.open = function(size, direction)
    ui.open(size, direction)
end

M.close = function()
    if ui.is_open() then
        ui.close()
    end
end

return M
