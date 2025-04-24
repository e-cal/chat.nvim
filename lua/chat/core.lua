local config = require("chat.config")
local api = require("chat.api")

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
						print("[chat.nvim] inserting file: " .. filename)
						local file = io.open(filename, "r")
						if not file then
							print("[chat.nvim] error opening file: " .. filename)
						else
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
					print("[chat.nvim] inserting file: " .. filename)
					-- insert the contents of the file
					local file = io.open(filename, "r")
					if not file then
						print("[chat.nvim] error opening file: " .. filename)
					else
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
			print("[chat.nvim] Generated title: " .. title)
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
		print("[chat.nvim] Skipping empty user message")
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
		print("[chat.nvim] Generating title...")
		generate_title(messages, bufnr)
	end

	local on_complete = function(err, _)
		if err then
			vim.api.nvim_err_writeln("[chat.nvim] Error streaming response: " .. err)
		end

		vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "", "", config.opts.delimiters.user, "", "" })

		require("chat.actions").format_chat(bufnr)

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

M.inline = function(context, _model)
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]

	local messages = {
		{ role = "system", content = config.opts.inline.system_message },
		{ role = "user", content = context },
	}
	-- P(messages)

	local on_chunk = function(err, chunk)
		if err then
			vim.api.nvim_err_writeln("Error streaming response: " .. err)
			return
		end
		if chunk then
			for chunk_json in chunk:gmatch("[^\n]+") do
				local raw_json = string.gsub(chunk_json, "^data: ", "")
				local ok, chunk_data = pcall(vim.json.decode, raw_json)
				if not ok then
					goto continue
				end

				-- print("on_chunk")
				-- P(chunk_data)

				local chunk_content
				if chunk_data.choices ~= nil then -- openai-style api
					if chunk_data.choices[1].delta ~= nil then
						chunk_content = chunk_data.choices[1].delta.content
					else -- base model
						chunk_content = chunk_data.choices[1].text
					end
				elseif chunk_data.type == "content_block_delta" then -- anthropic api
					chunk_content = chunk_data.delta.text
				end
				if chunk_content == nil then
					goto continue
				end

				local lines = vim.split(chunk_content, "\n")
				for i, line in ipairs(lines) do
					if i == 1 then
						local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
						local new_line = current_line:sub(1, col) .. line .. current_line:sub(col + 1)
						vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
						col = col + #line
					else
						row = row + 1
						vim.api.nvim_buf_set_lines(bufnr, row, row, false, { line })
						col = #line
					end
				end
				vim.api.nvim_win_set_cursor(0, { row + 1, col })

				::continue::
			end
		end
	end

	local on_complete = function(err, _)
		if err then
			vim.api.nvim_err_writeln("Error completing inline response: " .. err)
		end
	end

	local model
	if _model == "default" then
		model = config.opts.inline.instruct_model
	elseif _model == "base" then
		model = config.opts.inline.base_model
	else
		model = _model
	end

	api.request({
		messages = messages,
		model = model,
		temp = config.opts.inline.temp,
		bufnr = bufnr,
		on_complete = on_complete,
		stream_response = true,
		on_chunk = on_chunk,
	})
end

M.stop_generation = function()
	vim.g.chat_stop_generation = true
	print("[chat.nvim] Stopping generation")
end

return M
