local M = {}

-- Users can provide custom mappings of model alias to api model name
-- can also be used to set the provider for a model (e.g. aliasing a gpt model to openrouter to use that over the openai api)
M.default_model_aliases = {
	openrouter = {
		["k2"] = "moonshotai/kimi-k2",
		["deepseek"] = "deepseek/deepseek-v3.2-exp",
        ["qwen"] = "qwen/qwen3-235b-a22b-2507",
        ["glm"] = "z-ai/glm-4.6",

		["gemini-flash"] = "google/gemini-2.5-flash",
		["gemini-3"] = "google/gemini-3-pro-preview",

		["grok"] = "x-ai/grok-4",
        ["grok-4-fast"] = "x-ai/grok-4-fast",
        ["grok-code"] = "x-ai/grok-code-fast-1",

		["devstral"] = "mistralai/devstral-medium",
		["devstral-small"] = "mistralai/devstral-small",

	},
	anthropic = {
		["opus"] = "claude-opus-4-20250514",
		["claude-opus"] = "claude-opus-4-20250514",
		["claude-4-opus"] = "claude-opus-4-20250514",
		["sonnet"] = "claude-sonnet-4-20250514",
		["sonnet-4"] = "claude-sonnet-4-20250514",
		["claude-4-sonnet"] = "claude-sonnet-4-20250514",
		["sonnet-4.5"] = "claude-sonnet-4-5",
	},
	groq = {
		["llama3-8b"] = "llama3-8b-8192",
		["llama3-70b"] = "llama3-70b-8192",
		["mixtral"] = "mixtral-8x7b-32768",
		["mixtral-8x7b"] = "mixtral-8x7b-32768",
		["gemma-7b"] = "gemma-7b-it",
		["llama-3.1-8b"] = "llama-3.1-8b-instant",
		["llama-3.1-70b"] = "llama-3.1-70b-versatile",
		["groq/r1"] = "deepseek-r1-distill-llama-70b",
		["groq/k2"] = "moonshotai/kimi-k2-instruct",
	},
}

M.defaults = function()
	return {
		dir = vim.fn.stdpath("data") .. "/chat-nvim", -- dir to save/load chats
		save_to_working_dir = false, -- save new chats to the current working directory instead of the global chat dir
		api_keys = {
			openai = function()
				return os.getenv("OPENAI_API_KEY") or vim.fn.input("OpenAI API Key: ")
			end,
			anthropic = function()
				return os.getenv("ANTHROPIC_API_KEY") or vim.fn.input("Anthropic API Key: ")
			end,
			deepseek = function()
				return os.getenv("DEEPSEEK_API_KEY") or vim.fn.input("DeepSeek API Key: ")
			end,
			groq = function()
				return os.getenv("GROQ_API_KEY") or vim.fn.input("Groq API Key: ")
			end,
			cerebras = function()
				return os.getenv("CEREBRAS_API_KEY") or vim.fn.input("Cerebras API Key: ")
			end,
			fireworks = function()
				return os.getenv("FIREWORKS_API_KEY") or vim.fn.input("Fireworks AI API Key: ")
			end,
			topology = function()
				return os.getenv("TOPOLOGY_API_KEY") or vim.fn.input("Topology API Key: ")
			end,
			hyperbolic = function()
				return os.getenv("HYPERBOLIC_API_KEY") or vim.fn.input("Hyperbolic API Key: ")
			end,
			openrouter = function()
				return os.getenv("OPENROUTER_API_KEY") or vim.fn.input("OpenRouter API Key: ")
			end,
		},
		default = { -- default values for chat parameters (overwritten if changed inline in chat)
			title = "# New Chat",
			model = "sonnet-4",
			temp = 0.8, -- model temperature
			system_message = [[You are an expert programmer working alongside an expert colleague. 
Your colleague will ask you various questions about their code and ask you to assist with some coding tasks. 
Answer concisely and when asked for code avoid unnecessary verbose explanation.
]],
		},
		title_model = "google/gemini-2.0-flash-lite-001", -- model used to generate chat titles
		auto_scroll = true, -- scroll to bottom of chat when response is finished
		auto_format = false, -- automatically format the chat on save
		wrap = true, -- enable line wrap (j/k are bound to gj and gk in the chat buffer so line wrap doesn't suck)
		scroll_on_focus = false, -- automatically scroll to the bottom when chat is focused
		code_register = "c", -- register to use for yanking/pasting code
		print_provider = false, -- print model and provider info when making requests
		debug = false, -- enable debug logging for API requests and responses
		finder = "telescope", -- "telescope" or "fzf" - determines which finder to use for opening chats
		keymap = {
			send_message = "<CR>", -- normal mode keybind in chat windows to send message
			yank_code = "<leader>cy", -- yank the fenced code block under cursor into the code register
			paste_code = "<leader>cp", -- paste from the code register (empty string to unset)
			delete_chat = "<C-d>", -- keymap to delete a chat (in telescope menu)
			stop_generation = "<C-c>",
		},
		delimiters = { -- delimiters for sections of the chat
			settings = "## Settings",
			model = "> Model: ",
			temp = "> Temperature: ",
			reasoning = "> Reasoning: ",
			system = "> System:",
			chat = "## Chat",
			user = "### User",
			assistant = "### Assistant",
			file = "> @",
			entropix_save_path = "> Save: ",
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
	M.model_aliases = vim.deepcopy(M.default_model_aliases)
	if opts.model_maps then
		for provider, model_map in pairs(opts.model_maps) do
			M.model_aliases[provider] = vim.tbl_deep_extend("force", M.model_aliases[provider] or {}, model_map)
		end
	end
end

return M
