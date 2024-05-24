local M = {}

M.defaults = function()
	return {
		ui = {
			size = 40, -- percent of screen
			direction = "right", -- left, right, top, bottom, center
			wrap = false, -- enable line wrap (j/k are bound to gj and gk in the chat buffer so line wrap doesn't suck)
		},
		dir = vim.fn.stdpath("data") .. "/chat-nvim", -- dir to save/load chats
		delimiters = { -- delimiters for sections of the chat
			settings = "## Settings",
			model = "> Model: ",
			system = "> System Message",
			chat = "## Chat",
			user = "> User",
			assistant = "> Assistant",
		},
		openai_api_key = function()
			return os.getenv("OPENAI_API_KEY") or vim.fn.input("OpenAI API Key: ")
		end,
        default_title = "# New Chat",
		default_model = "gpt-4o", -- currently only supports openai gpt models
		title_model = "gpt-3.5-turbo", -- model used to generate chat titles
		default_system_message = "You are an expert programmer working alongside an expert colleague. Your colleague will ask you various questions about their code and ask you to assist with some coding tasks. Answer concisely and when asked for code avoid unnecessary verbose explanation.",
		auto_scroll = true, -- scroll to bottom of chat when response is finished
		auto_gq = true, -- automatically split lines with gq (ignores code and headings)
	}
end

M.setup = function(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", {}, M.defaults(), opts)
end

return M
