local config = require("chat.config")
local api = require("chat.api")
local actions = require("chat.actions")

local M = {}

local function parse_messages(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local messages = {}
	local role = nil
	local content = {}
	local model = config.opts.default.model
	local temp = nil
	local save_path = nil

	local in_system = false
	local sys_message = {}

	local in_chat = false

	for _, line in ipairs(lines) do
		if not in_chat then
			if line:find("^" .. config.opts.delimiters.model) then
				model = line:sub(config.opts.delimiters.model:len() + 1)
			elseif line:find("^" .. config.opts.delimiters.temp) then
				temp = tonumber(line:sub(config.opts.delimiters.temp:len() + 1))
			elseif line:find("^" .. config.opts.delimiters.entropix_save_path) then
				-- make it substitute "./" with the current directory
				save_path = line:sub(config.opts.delimiters.entropix_save_path:len() + 1)

				-- Get the current directory
				local current_dir = vim.fn.getcwd()

				-- Substitute "./" with the current directory
				save_path = save_path:gsub("^%./", current_dir .. "/")
			else
				in_chat = line == config.opts.delimiters.chat

				if in_system and not in_chat and (#sys_message > 0 or line ~= "") then
					if line:find("^" .. config.opts.delimiters.file) then
						local filename = line:sub(config.opts.delimiters.file:len() + 1)
						local file = io.open(filename, "r")
						if not file then
							vim.notify("error opening file: " .. filename, vim.log.levels.ERROR)
						else
						    vim.notify("injected file: " .. filename)
							local file_content = file:read("*a")
							local file_extension = filename:match("%.([^%.]+)$") or ""
							file:close()
							table.insert(sys_message, filename)
							table.insert(sys_message, "```" .. file_extension)
							for file_line in file_content:gmatch("[^\r\n]+") do
								table.insert(sys_message, file_line)
							end
							table.insert(sys_message, "```")
						end
					else
						table.insert(sys_message, line)
					end
				end

				if in_chat then
					if #sys_message > 0 then
						table.remove(sys_message, #sys_message) -- remove trailing blank line
						table.insert(messages, { role = "system", content = table.concat(sys_message, " \n ") })
					end
				else
					if line == config.opts.delimiters.system then
						in_system = true
					end
				end
			end
		else -- in chat
			-- start user message
			if line:find("^" .. config.opts.delimiters.user) then
				if role then -- save previous (assistant) message
					-- remove any blank lines from the end of the content
					while #content > 0 and content[#content] == "" do
						table.remove(content, #content)
					end
					table.insert(messages, { role = role, content = table.concat(content, " \n ") })
				end
				role = "user"
				content = {}

			-- start assistant message
			elseif line:find("^" .. config.opts.delimiters.assistant) then
				if role then -- save previous (user) message
					-- remove any blank lines from the end of the content
					while #content > 0 and content[#content] == "" do
						table.remove(content, #content)
					end
					table.insert(messages, { role = role, content = table.concat(content, " \n ") })
				end
				role = "assistant"
				content = {}

			-- add line to current message content
			elseif role and (#content > 0 or line ~= "") then
				if line:find("^" .. config.opts.delimiters.file) then -- insert file
					local filename = line:sub(config.opts.delimiters.file:len() + 1)
					-- insert the contents of the file
					local file = io.open(filename, "r")
					if not file then
						vim.notify("error opening file: " .. filename, vim.log.levels.ERROR)
					else
					    vim.notify("injected file: " .. filename)
						local file_content = file:read("*a")
						local file_extension = filename:match("%.([^%.]+)$") or ""
						file:close()
						table.insert(content, filename)
						table.insert(content, "```" .. file_extension)
						for file_line in file_content:gmatch("[^\r\n]+") do
							table.insert(content, file_line)
						end
						table.insert(content, "```")
					end
				else -- normal line
					table.insert(content, line)
				end
			end
		end
	end

	if role then -- messages are appended on role switch, so last gets left out (catch it here)
		while #content > 0 and content[#content] == "" do
			table.remove(content, #content)
		end
		table.insert(messages, { role = role, content = table.concat(content, "\n") })
	end

	-- P(messages)

	return messages, model, temp, save_path
end

local function generate_title(_messages, bufnr)
	local messages = {
		{ role = "system", content = "Your task is to summarize the conversation into a title" },
		_messages[2],
		{
			role = "user",
			content = "Write a short (1-5 words) title for this conversation based on the previous message. Only write the title, do not respond to the query.",
		},
	}

	local on_complete = function(err, res)
		if err then
			vim.api.nvim_err_writeln("[chat.nvim] Error generating conversation title: " .. err)
		elseif not res then
			return
		else
			local title = res.choices[1].message.content
			title = string.gsub(title, "[\n\r]", "")
			vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "# " .. title })
		end
	end

	api.request({
		messages = messages,
		model = config.opts.title_model,
		temp = 0.8,
		bufnr = bufnr,
		on_complete = on_complete,
	})
end

M.send_message = function()
	local bufnr = vim.api.nvim_get_current_buf()
	local messages, model, temp, save_path = parse_messages(bufnr)

	if messages[#messages].role == "user" and messages[#messages].content == "" then
		vim.notify("Skipping empty user message", vim.log.levels.WARN)
		return
	end

	-- remove any blank lines from the end of the buffer
	local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	while #buf_lines > 0 and buf_lines[#buf_lines] == "" do
		table.remove(buf_lines, #buf_lines)
	end
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, buf_lines)

	vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "", config.opts.delimiters.assistant, "", "" })

	if buf_lines[1] == config.opts.default.title then
		generate_title(messages, bufnr)
	end

	local on_complete = function(err, _)
		if err then
			vim.notify("Error streaming response: " .. err, vim.log.levels.ERROR)
		end

		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "", config.opts.delimiters.user, "", "" })


	    if vim.g.chat_formatting then
		    actions.format_chat(bufnr)
        end

		if config.opts.auto_scroll then
			vim.api.nvim_buf_call(bufnr, function()
				vim.cmd("normal! G")
			end)
		end
		vim.cmd("silent w!")
	end

	api.request({
		messages = messages,
		model = model,
		temp = temp,
		save_path = save_path,
		bufnr = bufnr,
		on_complete = on_complete,
		stream_response = true,
	})
end

M.stop_generation = function()
	vim.g.chat_stop_generation = true
	vim.notify("Cancelled generation")
end

return M
