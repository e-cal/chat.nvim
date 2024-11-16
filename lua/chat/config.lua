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
			deepseek = function()
				return os.getenv("DEEPSEEK_API_KEY") or vim.fn.input("DeepSeek API Key: ")
			end,
			groq = function()
				return os.getenv("GROQ_API_KEY") or vim.fn.input("Groq API Key: ")
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
			model = "claude-3.5-sonnet", -- model names will auto add the suffix if needed
			temp = 0.8, -- model temperature
			system_message = [[You are an expert programmer working alongside an expert colleague. 
Your colleague will ask you various questions about their code and ask you to assist with some coding tasks. 
Answer concisely and when asked for code avoid unnecessary verbose explanation.
]],
		},
		title_model = "meta-llama/llama-3.1-8b-instruct", -- model used to generate chat titles
		auto_scroll = true, -- scroll to bottom of chat when response is finished
		auto_format = true, -- automatically format the chat on save
		wrap = false, -- enable line wrap (j/k are bound to gj and gk in the chat buffer so line wrap doesn't suck)
		scroll_on_focus = false, -- automatically scroll to the bottom when chat is focused
		code_register = "c", -- register to use for yanking/pasting code
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
			system = "> System Message",
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
		inline = {
			base_model = "llama-3.1-405b-base",
			instruct_model = "claude-3.5-sonnet",
			system_message = [[You are an expert programmer working alongside an expert colleague. 
You will be given code snippets. 
Interpret comments as instructions on code that needs to be written if there isn't already code addressing the comment or if the comment requests refactoring.
Only respond with code, make all comments and explanation as code comments.
Do not respond or acknowledge the request in any way, just start coding.
Continue where the code leaves off, do not repeat existing code unless it needs to be changed.
Just start writing code, do not format as markdown or include any triple backticks.
Only do exactly as instructed, do not add code that was not explicitly asked for or described. Do not add more functionality than is asked for.
]],
			temp = 0.3, -- model temperature
			max_tokens = 512, -- max length of response
		},
	}
end

M.setup = function(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", {}, M.defaults(), opts)
end

return M
