local M = {}

M.defaults = function()
    return {
        ui = {
            -- width = 30,
            size = 30,
            direction = "right",
            wrap = true,
        },
    }
end

M.setup = function(opts)
    opts = opts or {}
    M.opts = vim.tbl_deep_extend("force", {}, M.defaults(), opts)
end

return M
