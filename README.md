# chat.nvim - Simple AI Chat

Chat with an LLM in neovim. No half baked bells and whistles, just chat with
the service of your choice and easy copy-pasting back and forth.

There's a ton of AI plugins these days, but I wasn't really satisfied with any of
them. So, I made another one! This probably has the least features out of any of
them, its just a simple chat window where chats are plain markdown files.

My goal is more or less to combine the simplicity of [gp.nvim](https://github.com/Robitx/gp.nvim) with the flexibility of [ogpt.nvim](https://github.com/huynle/ogpt.nvim).

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
- `<CR>` in normal mode sends your chat message
- all history can be edited as needed and will be sent as seen in the buffer
  - be careful not to change or forget the user/assistant prefixes (set in config) or messages will be merged

## Configuration

Defaults:
```lua
{
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
```


## TODO

- [-] Add model params to chat files
  - [x] set model inline
  - [ ] set other arbitrary params (temperature, etc)
- [x] Add auto paste selection when chat is focused from visual mode
- [ ] Add providers
  - [ ] anthropic
  - [ ] groq
