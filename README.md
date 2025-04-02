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
- _localhost_ (will need configuration in `lua/chat/api.lua`. See `entropix` provider)



## Configuration

Defaults:

```lua
{
  dir = vim.fn.stdpath("data") .. "/chat-nvim", -- dir to save/load chats
  api_keys = {
    openai = function()
      return os.getenv("OPENAI_API_KEY") or vim.fn.input("OpenAI API Key: ")
    end,
    -- ... repeated for all the providers ...
  },
  model_maps = {
    openrouter = {
      ["o1"] = "openai/o1-preview", -- maps the model name "o1" to use openrouter and expand into the proper api model name "openai/o1-preview"
      -- ...
    }
    -- ...
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
  title_model = "meta-llama/llama-3.1-8b-instruct", -- model used to generate chat titles
  auto_scroll = true, -- scroll to bottom of chat when response is finished
  auto_format = true, -- automatically format the chat on save
  wrap = false, -- enable line wrap (j/k are bound to gj and gk in the chat buffer so line wrap doesn't suck)
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
