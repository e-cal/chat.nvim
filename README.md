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

`ChatFocus`: 

### Usage Notes

- `<CR>` in normal mode sends your chat message
- `ChatFocus` has dynamic behavior:
  - _Chat is not open_: opens and focuses the chat window, with your most recent chat loaded
  - _Chat is open, not focused_: focuses the chat window
  - _Chat is open, focused_: focuses your previous editor
  - binding `ChatFocus` is the recommended way to navigate to and from the chat window, since
    `<C-w>h/j/k/l` does not work with popups
    - alternatively, `<C-w>w` does work and can also be used
- `ChatToggle` and `ChatClose` work as expected
- all history can be edited as needed and will be sent as seen in the buffer
  - be careful not to change or forget the user/assistant prefixes (set in config) or messages will be merged

## Configuration

Defaults:
```lua
{
		ui = {
			size = 40,
			direction = "right", -- left, right, top, bottom, center
			wrap = true, -- line wrap (j/k are bound to gj and gk in the chat buffer so line wrap doesn't suck)
		},
		dir = vim.fn.stdpath("data") .. "/chat-nvim", -- dir to save/load chats
		system = "You are an expert programmer working alongside an expert colleague. Your colleague will ask you various questions about their code and ask you to assist with some coding tasks. Answer concisely and when asked for code avoid unnecessary verbose explanation.",
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
```


## TODO

- [ ] Add model params to chat files
- [ ] Add auto-yank code in chat response
- [ ] Add auto paste selection when chat is focused from visual mode
- [ ] Add providers
  - [ ] Anthropic
  - [ ] Ollama
- [ ] Set provider / model on the fly from chat file (same as system prompt)
- [ ] Make more things settings
