local config = require("chat.config")

local M = {}
M.wrap_keymaps_active = {}

M.setup_buffer = function(bufnr)
	local key_opts = { noremap = true, silent = true, nowait = true, buffer = bufnr }

	-- Keymaps
	vim.keymap.set("n", config.opts.keymap.send_message, require("chat.core").send_message, key_opts)
	vim.keymap.set("n", config.opts.keymap.yank_code, require("chat.actions").yank_code, key_opts)
	vim.keymap.set("n", config.opts.keymap.stop_generation, require("chat.core").stop_generation, key_opts)

	-- Global paste keymap
	if config.opts.keymap.paste_code ~= "" then
		vim.keymap.set(
			{ "n", "v" },
			config.opts.keymap.paste_code,
			'"' .. config.opts.code_register .. "p",
			{ noremap = true, nowait = true }
		)
	end

	local opts = { buf = bufnr }
	vim.api.nvim_set_option_value("textwidth", vim.api.nvim_win_get_width(0) - 10, opts)

	if config.opts.wrap then
		vim.api.nvim_set_option_value("wrap", true, { win = 0 })
		vim.api.nvim_set_option_value("linebreak", true, { win = 0 })
		M.wrap_keymaps_active[bufnr] = false
		M.update_wrap(bufnr)
	elseif config.opts.auto_format then
		vim.api.nvim_set_option_value("formatoptions", "t", opts)
	end

	if config.opts.scroll_on_focus then
		vim.cmd("normal! G")
	end
end

M.update_wrap = function(bufnr)
	if not config.opts.wrap then
		return
	end

	local node = vim.treesitter.get_node()
	if not node then
		vim.api.nvim_set_option_value("wrap", true, { win = 0 })
		if not M.wrap_keymaps_active[bufnr] then
			local key_opts = { noremap = true, silent = true, nowait = true, buffer = bufnr }
			vim.keymap.set("n", "j", "gj", key_opts)
			vim.keymap.set("n", "k", "gk", key_opts)
			vim.keymap.set("n", "^", "g^", key_opts)
			vim.keymap.set("n", "$", "g$", key_opts)
			M.wrap_keymaps_active[bufnr] = true
		end
		return
	end

	while node and node:type() ~= "fenced_code_block" do
		node = node:parent()
	end

	local key_opts = { noremap = true, silent = true, nowait = true, buffer = bufnr }

	if node and node:type() == "fenced_code_block" then
		vim.api.nvim_set_option_value("wrap", false, { win = 0 })
		if M.wrap_keymaps_active[bufnr] then
			pcall(vim.keymap.del, "n", "j", { buffer = bufnr })
			pcall(vim.keymap.del, "n", "k", { buffer = bufnr })
			pcall(vim.keymap.del, "n", "^", { buffer = bufnr })
			pcall(vim.keymap.del, "n", "$", { buffer = bufnr })
			M.wrap_keymaps_active[bufnr] = false
		end
	else
		vim.api.nvim_set_option_value("wrap", true, { win = 0 })
		if not M.wrap_keymaps_active[bufnr] then
			vim.keymap.set("n", "j", "gj", key_opts)
			vim.keymap.set("n", "k", "gk", key_opts)
			vim.keymap.set("n", "^", "g^", key_opts)
			vim.keymap.set("n", "$", "g$", key_opts)
			M.wrap_keymaps_active[bufnr] = true
		end
	end
end

return M

