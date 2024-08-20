# chat.nvim

Chat with an LLM in a markdown file and complete code inline. For people who
prefer the API playground to chatbot uis.

No fancy limiting chat ui, just parses the file as a chat using the delimiters
and streams the response into the file. Works like an API playground.

- Change model parameters in-line
- Revise chat history as needed (its just a markdown file)
- Swap the model mid conversation
- Open chat as a full buffer or in a popup
  - or one-shot send visual selection and stream response directly into the current buffer
- Configurable auto formatting, code yank/paste keybinds, and other quality of life features

![screenshot](https://github.com/user-attachments/assets/e49f8deb-aadb-4b1a-928f-ad91912b71db)

## Installation

Using lazy.nvim

```lua
{
  "e-cal/chat.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
    "nvim-telescope/telescope.nvim",
  },
  opts = {
    -- your config, or leave empty for defaults
    -- (required even if empty to load plugin)
  }
}
```

## Usage

### Commands

- `ChatInline` or `ChatInline replace` to have the llm complete inline
  - if called from visual mode, sends visual selection
  - if called from normal mode, sends buffer up to (and including) the cursor line
- `ChatStop` to stop any current llm generation

**in chat buffers:**

- `<CR>` in normal mode sends your chat message
  - all chat history can be edited (its just markdown) and will be parsed using the
    prefixes defined in your config
- `ChatFocus` has dynamic behavior:
  - _Chat is not open_: opens and focuses the chat window, with your most recent chat loaded
  - _Chat is open, not focused_: focuses the chat window
  - _Chat is open, focused_: focuses your previous editor
  - binding `ChatFocus` is the recommended way to navigate to and from the chat window, since
    `<C-w>h/j/k/l` does not work with popups
    - alternatively, `<C-w>w` does work and can also be used
- `ChatToggle` to toggle ui
- `ChatClose` to close ui
- `ChatNew` to start a new chat
- `ChatOpen` to open an existing chat
- `ChatDelete` to delete the current chat (and close ui)
- `ChatSetupBuffer` to setup the current buffer as a chat buffer (regardless of
  if its a `.chat` file or not)
  - useful to reset the textwidth after resizing a popup

### Models

Set the model at the top of chat buffers and in the config for inline
completions.

- **OpenAI**: all `gpt` models supported
  - use the model name as it appears in the API
  - e.g. `gpt-3.5-turbo`, `gpt-4o`, `gpt-4`, `gpt-4-0613`
- **Anthropic**: all `claude` models supported
  - can use the model name with or without the date suffix
  - can use `3.5` or `3-5`
  - e.g. `claude-3.5-sonnet`, `claude-3-5-sonnet`, `claude-3-opus`, `claude-3-haiku-20240307`
- **DeepSeek**: `deepseek-chat` (DeepSeek-V2-062) and `deepseek-coder` (DeepSeek-Coder-V2-0724)
- **Topology**: `topology-tiny`, `topology-small`, and `topology-medium`
- **Groq**: all models supported
  - can use the model name with or without the suffix (date/type)
  - must add `groq/` prefix to use groq for Llama 3.1 405B (for 3.1 only 8B defaults to groq without the prefix)
  - e.g. `llama3-8b`, `llama3-70b-8192`, `mixtral-8x7b`, `gemma-7b`, `llama-3.1-8b`, `llama-3.1-70b`, `groq/llama-3.1-405b`
- **Fireworks AI**: `llama-3.1-405b`, `fireworks/llama-3.1-70b`, `fireworks/llama-3.1-8b`
- **OpenRouter**: all models supported, enter model with prefix as it is on [OpenRouter](https://openrouter.ai/models)
  - e.g. `meta-llama/llama-3.1-8b-instruct:free`, `nousresearch/hermes-3-llama-3.1-70b`, `meta-llama/llama-3.1-405b`, `perplexity/llama-3.1-sonar-large-128k-online`

## Configuration

Defaults:

```lua
{
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
    openrouter = function()
      return os.getenv("OPENROUTER_API_KEY") or vim.fn.input("OpenRouter API Key: ")
    end,
  },
  default = { -- default values for chat parameters (overwritten if changed inline in chat)
    title = "# New Chat",
    model = "claude-3.5-sonnet", -- model names will auto add the suffix if needed
    temp = 0, -- model temperature
    system_message = [[You are an expert programmer working alongside an expert colleague.
Your colleague will ask you various questions about their code and ask you to assist with some coding tasks.
Answer concisely and when asked for code avoid unnecessary verbose explanation.
]],
  },
  title_model = "meta-llama/llama-3.1-8b-instruct:free", -- model used to generate chat titles
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
    user = "> User",
    assistant = "> Assistant",
  },
  popup = {
    size = 40, -- percent of screen
    direction = "right", -- left, right, top, bottom, center
  },
  inline = {
    model = "claude-3.5-sonnet",
    temp = 0, -- model temperature
    system_message = [[You are an expert programmer working alongside an expert colleague.
You will be given code snippets.
Treat comments that don't have accompanying code as instructions on what needs to be done.
Only respond with code, make all comments and explanation as code comments.
Do not respond or acknowledge the request in any way, just start coding.
Continue where the code leaves off, do not repeat existing code unless it needs to be changed.
There is no need to fence the code with triple backticks, just start writing code.
Only do exactly as instructed, do not add code that was not explicitly asked for or described. Do not add more functionality than is asked for.
]],
  },
}
```
