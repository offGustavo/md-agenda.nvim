local common = require("md-agenda.common")

local vim = vim

local up = {} --update progress

--action: "cancel" or "check"
up.updateTaskProgress = function(filepath, itemLineNum, progressCount, bufferRefreshNum)

	--Check if the given buffer is modified. If so, save the modifications first.
	if bufferRefreshNum and vim.api.nvim_buf_is_valid(bufferRefreshNum) and
	vim.api.nvim_buf_get_option(bufferRefreshNum, 'modified') then
		vim.cmd("b "..bufferRefreshNum.."| w")
	end

	-- Read the lines from the specified file
	local readFile = io.open(filepath, "r")
	if not readFile then
		print("Could not open file: " .. filepath)
		return
	end

	local fileLines = {}
	for line in readFile:lines() do
		table.insert(fileLines, line)
	end
	readFile:close()

	local lineContent = fileLines[itemLineNum]

	local taskType = lineContent:match("^ *#+ ([A-Z]+): .*$")
	if taskType then

		if (not common.isTodoItem(taskType)) and taskType~="HABIT" and taskType~="DONE" and taskType~="DUE" and taskType~="INFO" and taskType~="CANCELLED" then
			print("Not a task or has not a supported task type")
			return
		end

		local newTaskStr = lineContent

		local progressCurrent, progressDesired = lineContent:match(".*%(([0-9]+)/([0-9]+)%).*")
		--if there is a progress indicator in the task
		if progressCurrent and progressDesired then
			newTaskStr = newTaskStr:gsub("%([0-9]+/[0-9]+%)", "("..progressCount.."/"..progressDesired..")")
		else
			print("The task has no progress indicator.")
			return
		end

		fileLines[itemLineNum] = newTaskStr
		---

		--Save new modified lines back to the file
		local writeFile = io.open(filepath, "w")
		if not writeFile then
			print("Could not open file for writing: " .. filepath)
			return
		end

		writeFile:write(table.concat(fileLines, "\n") .. "\n")
		writeFile:close()

		--Refresh the given buffer's content
		if bufferRefreshNum and vim.api.nvim_buf_is_valid(bufferRefreshNum) then
			vim.cmd("checktime "..tostring(bufferRefreshNum))
		end
	else
		print("Not a task")
	end
end

return up
