local M = {}

M.defaults = function()
	return {
		dir = vim.fn.stdpath("data") .. "/chat-nvim", -- dir to save/load chats
		api_keys = {
			openai = function()
				return os.getenv("OPENAI_API_KEY") or vim.fn.input("OpenAI API Key: ")
			end,
			anthropic = function()
				return os.getenv("ANTHROPIC_API_KEY") or vim.fn.input("Anthropic API Key: ")
			end,
			groq = function()
				return os.getenv("GROQ_API_KEY") or vim.fn.input("Groq API Key: ")
			end,
		},
		default = { -- default values for chat parameters (overwritten if changed inline in chat)
			title = "# New Chat",
			model = "claude-3.5-sonnet", -- model names will auto add the suffix if needed
			temp = 0, -- model temperature
			system_message = "You are an expert programmer working alongside an expert colleague. Your colleague will ask you various questions about their code and ask you to assist with some coding tasks. Answer concisely and when asked for code avoid unnecessary verbose explanation.",
		},
		title_model = "gpt-3.5-turbo", -- model used to generate chat titles
		auto_scroll = true, -- scroll to bottom of chat when response is finished
		auto_format = true, -- automatically format the chat on save
		wrap = false, -- enable line wrap (j/k are bound to gj and gk in the chat buffer so line wrap doesn't suck)
		scroll_on_focus = false, -- automatically scroll to the bottom when chat is focused
		code_register = "c", -- register to use for yanking/pasting code
		keymap = {
			-- in chat (normal mode)
			send_message = "<CR>",
			yank_code = "<leader>cy", -- yank the fenced code block under cursor into the code register
			paste_code = "<leader>cp", -- paste from the code register (empty string to unset)
			-- in telescope menu
			delete_chat = "<C-d>", -- keymap to delete a chat
		},
		delimiters = { -- delimiters for sections of the chat
			settings = "## Settings",
			model = "> Model: ",
			temp = "> Temperature: ",
			system = "> System Message",
			chat = "## Chat",
			user = "> User",
			assistant = "> Assistant",
		},
		popup = {
			size = 40, -- percent of screen
			direction = "right", -- left, right, top, bottom, center
		},
	}
end

M.setup = function(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", {}, M.defaults(), opts)
end

return M
