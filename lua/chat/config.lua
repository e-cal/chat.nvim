local M = {}

-- Users can provide custom mappings of model alias to api model name
-- can also be used to set the provider for a model (e.g. aliasing a gpt model to openrouter to use that over the openai api)
M.default_model_maps = {
	openrouter = {
		-- ["o1"] = "openai/o1",
        -- ["o1-pro"] = "openai/o1-pro",
		-- ["o1-mini"] = "openai/o1-mini",
		-- ["o3-mini"] = "openai/o3-mini",
		-- ["o3-mini-high"] = "openai/o3-mini-high",
        -- ["o3"] = "openai/o3",
        -- ["o4-mini"] = "openai/o4-mini",
        -- ["gpt-4.1"] = "openai/gpt-4.1",
        -- ["gpt-4.5"] = "openai/gpt-4.5-preview",
		["openrouter/r1"] = "deepseek/deepseek-r1",
		["gemini-2.0-pro"] = "google/gemini-2.0-pro-exp-02-05:free",
		["gemini-2.0-flash"] = "google/gemini-2.0-flash-001",
		["gemini-2.5-free"] = "google/gemini-2.5-pro-exp-03-25:free",
		["gemini-2.5-pro"] = "google/gemini-2.5-pro-preview",
		["gemini-pro"] = "google/gemini-2.5-pro-preview",
		["gemini-flash"] = "google/gemini-2.5-flash-preview",
		["gemini-flash-thinking"] = "google/gemini-2.0-flash-thinking-exp:free",
		["grok"] = "x-ai/grok-3-beta",
		["grok-mini"] = "x-ai/grok-3-mini-beta",
	},
	openai = {
		["o1"] = "o1-2024-12-17",
		["o3-mini"] = "o3-mini-2025-01-31",
	},
	anthropic = {
		-- claude 3 aliases
		["claude-3-haiku"] = "claude-3-haiku-20240307",
		["claude-3-sonnet"] = "claude-3-sonnet-20240229",
		["claude-3-opus"] = "claude-3-opus-20240229",
		-- claude 3.5 aliases
		["claude-3.5-haiku"] = "claude-3-5-haiku-20241022",
		["claude-3.5-haiku-latest"] = "claude-3-5-haiku-latest",
		["claude-3.5-sonnet"] = "claude-3-5-sonnet-20240620",
		-- new sonnet
		["claude-3.5-sonnet-new"] = "claude-3-5-sonnet-20241022",
		["claude-3.6-sonnet"] = "claude-3-5-sonnet-20241022",
		["claude-3.5-sonnet-2"] = "claude-3-5-sonnet-20241022",
		["claude-3.5-sonnet-latest"] = "claude-3-5-sonnet-latest",
		-- 3.7 sonnet
		["claude-3.7-sonnet"] = "claude-3-7-sonnet-20250219",
		["claude-3.7-sonnet-latest"] = "claude-3-7-sonnet-latest",
		-- versionless aliases
		["claude"] = "claude-3-7-sonnet-latest",
		["claude-sonnet"] = "claude-3-7-sonnet-latest",
		["sonnet-latest"] = "claude-3-7-sonnet-latest",
		["haiku"] = "claude-3-5-haiku-latest",
		["claude-haiku"] = "claude-3-5-haiku-latest",
	},
	deepseek = {
		["r1"] = "deepseek-reasoner",
		["deepseek-v3"] = "deepseek-chat",
		["deepseek-chat"] = "deepseek-chat",
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
	},
	cerebras = {
		["cerebras/llama-3.1-8b"] = "llama-3.1-8b",
		["cerebras/llama-3.1-70b"] = "llama-3.1-70b",
		["cerebras/llama-3.3-70b"] = "llama-3.3-70b",
	},
	fireworks = {
		["fireworks/llama-3.1-8b"] = "llama-v3p1-8b-instruct",
		["fireworks/llama-3.1-70b"] = "llama-v3p1-70b-instruct",
		["fireworks/llama-3.1-405b"] = "llama-v3p1-405b-instruct",
	},
	hyperbolic = {
		["llama-405b"] = "meta-llama/Meta-Llama-3.1-405B-Instruct",
		["llama-3.1-405b"] = "meta-llama/Meta-Llama-3.1-405B-Instruct",
		["llama-3.1-70b-bf16"] = "meta-llama/Meta-Llama-3.1-70B-Instruct",
		["llama-3.1-8b-bf16"] = "meta-llama/Meta-Llama-3.1-8B-Instruct",
	},
	hyperbolic_base = {
		["llama-3.1-405b-base"] = "meta-llama/Meta-Llama-3.1-405B",
		["llama-3.1-405b-fp8-base"] = "meta-llama/Meta-Llama-3.1-405B-FP8",
	},
	entropix = {
		["entropix"] = "llama-1b",
		["llama-1b"] = "llama-1b",
		["smollm"] = "smollm",
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
			model = "claude-3.7-sonnet",
			temp = 0.8, -- model temperature
			system_message = [[You are an expert programmer working alongside an expert colleague. 
Your colleague will ask you various questions about their code and ask you to assist with some coding tasks. 
Answer concisely and when asked for code avoid unnecessary verbose explanation.
]],
		},
		title_model = "google/gemini-2.0-flash-lite-001", -- model used to generate chat titles
		auto_scroll = true, -- scroll to bottom of chat when response is finished
		auto_format = true, -- automatically format the chat on save
		wrap = true, -- enable line wrap (j/k are bound to gj and gk in the chat buffer so line wrap doesn't suck)
		scroll_on_focus = false, -- automatically scroll to the bottom when chat is focused
		code_register = "c", -- register to use for yanking/pasting code
		print_provider = false, -- print model and provider info when making requests
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
			instruct_model = "claude-3.7-sonnet",
			system_message = [[You are an expert programmer working alongside an expert colleague. 
You will be given code snippets. 
Interpret comments as instructions on code that needs to be written if there isn't already code addressing the comment or if the comment requests refactoring.
Only respond with code, make all comments and explanation as code comments.
Do not respond or acknowledge the request in any way, just start coding. Do not explain in prose what you are doing or how the code works. Code only.
Continue where the code leaves off, do not repeat existing code. Only show the modified code.
Just start writing code, do not format as markdown, write plain code.
Only do exactly as instructed, do not add code that was not explicitly asked for or described. Do not add more functionality than is asked for. Do not continue the program beyond what specific functionality the user requests.
]],
			temp = 0.1, -- model temperature
			max_tokens = 512, -- max length of response
		},
	}
end

M.setup = function(opts)
	opts = opts or {}
	M.opts = vim.tbl_deep_extend("force", {}, M.defaults(), opts)
	M.model_maps = vim.deepcopy(M.default_model_maps)
	if opts.model_maps then
		for provider, model_map in pairs(opts.model_maps) do
			M.model_maps[provider] = vim.tbl_deep_extend("force", M.model_maps[provider] or {}, model_map)
		end
	end
end

return M
