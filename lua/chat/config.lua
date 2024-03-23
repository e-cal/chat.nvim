local M = {}

M.defaults = function()
	return {
		ui = {
			size = 40,
			direction = "right", -- left, right, top, bottom, center
			wrap = true, -- line wrap (j/k are bound to gj and gk in the chat buffer so line wrap doesn't suck)
		},
		dir = vim.fn.stdpath("data") .. "/chat-nvim", -- dir to save/load chats
		system = "You are an expert programmer working alongside an expert colleague. Your colleague will ask you various questions about their code and ask you to assist with some coding tasks. Answer concisely and when asked for code avoid unnecessary verbose explanation.",
        system_prefix = "### System Message",
		user_prefix = "## User",
		assistant_prefix = "### Assistant",
		openai_api_key = function()
			return os.getenv("OPENAI_API_KEY") or vim.fn.input("OpenAI API Key: ")
		end,
		default_provider = "openai", -- currently the only one supported... more to come
		openai_model = "gpt-3.5-turbo",
		auto_scroll = true, -- scroll to bottom of chat when response is finished
		auto_save = true, -- save chat on response
	}
end

M.setup = function(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", {}, M.defaults(), opts)
end

return M
