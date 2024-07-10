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

![screenshot](https://github.com/e-cal/chat.nvim/assets/47398876/6dcadab5-32e9-4dbd-9706-d62f6fa043b4)

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

- `ChatInline` or `ChatInline replace` to have the llm complete inline
  - if called from visual mode, sends visual selection
  - if called from normal mode, sends buffer up to (and including) the cursor line
- `ChatStop` to stop any current llm generation

### Chat Buffers

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
```
