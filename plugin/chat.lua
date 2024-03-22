local get_direction_options = function()
    return { "top", "bottom", "left", "right", "center" }
end

vim.api.nvim_create_user_command("ChatToggle", function(opts)
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
end, { nargs = "?", complete = function() return get_direction_options() end })

vim.api.nvim_create_user_command("ChatOpen", function(opts)
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
    require("chat").open(size, direction)
end, { nargs = "?", complete = function() return get_direction_options() end })

vim.api.nvim_create_user_command("ChatClose", function()
    require("chat").close()
end, {})
