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
    "nvim-telescope/telescope.nvim", -- Default finder (can be replaced with junegunn/fzf.vim)
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

Set the model at the top of chat buffers and in the config for inline completions.

Model mappings (alias -> provider api model) are defined your config, see `lua/chat/config.lua` for the full list and to configure custom model aliases.

Any model name without a configured mapping will automatically try to match a provider pattern (e.g. anything with `gpt` in the name will try to use OpenAI) and fallback to OpenRouter if no matching pattern is found (so you can always just use OpenRouter model ids and it will just work).

Supported APIs:
- OpenAI
- Anthropic
- DeepSeek
- **OpenRouter** (fallback)
- Groq
- Cerebras
- Hyperbolic
- FireworksAI




## Configuration

Defaults:

```lua
{
  dir = vim.fn.stdpath("data") .. "/chat-nvim", -- dir to save/load chats
  save_to_working_dir = false, -- save new chats to the current working directory instead of the global chat dir
  api_keys = {
    openai = function()
      return os.getenv("OPENAI_API_KEY") or vim.fn.input("OpenAI API Key: ")
    end,
    -- ... repeated for all the providers ...
  },
  providers = {
    openrouter = {
      ["o1"] = "openai/o1-preview", -- maps the model name "o1" to use openrouter and expand into the proper api model name "openai/o1-preview"
      -- ...
    }
    -- ...
  },
  defaults = { -- default values for chat parameters (overwritten if changed inline in chat)
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
  -- Optional: configure inline completion (used by ChatInline command)
  -- inline = {
  --   instruct_model = "sonnet-4.5", -- model for code instruction following
  --   base_model = "gpt-4o", -- model for base completions (optional)
  --   system_message = [[You are an expert programmer...]],
  --   temp = 0.1,
  --   max_tokens = 512,
  -- },

}
```

### API Key Management

It is recommended to either export your api keys in your shell environment and
use the api key functions as they are, or define your own.

For example, if you have your openai api key stored as text files on your system you might change the function to:

```lua
api_keys = {
  openai = function()
    local f = assert(io.open(os.getenv("HOME") .. "/<path to key>", "r"))
    local api_key = string.gsub(f:read("*all"), "\n", "")
    f:close()
    return api_key
  end,
}
```
