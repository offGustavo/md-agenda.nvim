local common = require("md-agenda.common")

local vim = vim

local ta = {} --task action

--action: "cancel" or "check"
ta.taskAction = function(filepath, itemLineNum, action, bufferRefreshNum)

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

        local currentTime = os.time()

        local taskProperties = common.getTaskProperties(fileLines, itemLineNum, false)

        local scheduledTimeStr, parsedScheduled
        local scheduled=taskProperties["Scheduled"]
        if scheduled then
            scheduledTimeStr = scheduled
            parsedScheduled = common.parseTaskTime(scheduledTimeStr)

            if not parsedScheduled then print("for some reason, scheduled could not correctly parsed") return end

            if currentTime < parsedScheduled["unixTime"] then
                print("Cannot check the task. The scheduled time is not been arrived yet")
                return
            end
        end

        if taskType=="HABIT" and (not scheduled) then
            print("Cannot check the task. Habits must include a Scheduled property")
            return
        end

        local deadlineTimeStr, parsedDeadline
        local deadline=taskProperties["Deadline"]
        if deadline then
            deadlineTimeStr = deadline
            parsedDeadline = common.parseTaskTime(deadlineTimeStr)

            if not parsedDeadline then print("for some reason, deadline could not correctly parsed") return end
        end

        if deadline and scheduled and parsedDeadline["nextUnixTime"] and parsedScheduled["nextUnixTime"] then
            print("Only one property can contain a repeat indicator.")
            return
        end

        ---------------------TODO/HABIT CASE---------------------
        if common.isTodoItem(taskType) or taskType=="HABIT" then

            local newTaskStr = lineContent

            --/IF ITS A NON-REPEATING TASK/--
            if (deadline and not parsedDeadline["nextUnixTime"]) or (scheduled and not parsedScheduled["nextUnixTime"]) or
            (not scheduled and not deadline) then
				if action == "cancel" then
					newTaskStr = lineContent:gsub("# [A-Z]+:","# CANCELLED:")
					fileLines[itemLineNum] = newTaskStr

				else
					newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DONE:")

					if deadline and parsedDeadline["unixTime"] < currentTime then
						newTaskStr = newTaskStr:gsub("DONE:","DUE:")
					end

					--The start line is 0-indexed unlike lua. thus, end line (excluded) is lineNum and changed line is lineNum-1.
					fileLines[itemLineNum] = newTaskStr
					fileLines = common.addPropertyToItem(fileLines, itemLineNum, "Completion", os.date("%Y-%m-%d %H:%M", currentTime))
				end

            ------------------------

            --/IF ITS A REPEATING TASK/--
            elseif (deadline and parsedDeadline["nextUnixTime"]) or (scheduled and parsedScheduled["nextUnixTime"]) then

				--if the repeat indicator is on Scheduled property, and current day exceeds the deadline
				if deadline and scheduled and parsedScheduled["nextUnixTime"] and
				currentTime > parsedDeadline["unixTime"] then
					if action=="cancel" then
						newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DUE:")
					else newTaskStr = newTaskStr:gsub("# [A-Z]+:","# CANCELLED:") end
					return
				--if the repeat indicator is on Scheduled property, and the next scheduled time exceeds the deadline
				elseif deadline and scheduled and parsedScheduled["nextUnixTime"] and
				parsedScheduled["nextUnixTime"] > parsedDeadline["unixTime"] then
					if action=="cancel" then
						newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DONE:")
					else newTaskStr = newTaskStr:gsub("# [A-Z]+:","# CANCELLED:") end
					return
				end

				local progressCurrent, progressDesired = lineContent:match(".*%(([0-9]+)/([0-9]+)%).*")
				--if there is a progress indicator in the task
				if progressCurrent and progressDesired then
					if action == "cancel" then
						fileLines = common.addItemToLogbook(fileLines, itemLineNum, "- CANCELLED: `"..os.date("%Y-%m-%d %H:%M",os.time()).."` `("..progressCurrent.."/"..progressDesired..")`")
					else
						if tonumber(progressCurrent)==0 then
							print("Cannot check the task. No progress has been made.")
							return
						end

						--do not mark as done if the progress is not completed
						if tonumber(progressCurrent) < tonumber(progressDesired) then
							fileLines = common.addItemToLogbook(fileLines, itemLineNum, "- PROGRESS: `"..os.date("%Y-%m-%d %H:%M",os.time()).."` `("..progressCurrent.."/"..progressDesired..")`")
						else
							fileLines = common.addItemToLogbook(fileLines, itemLineNum, "- DONE: `"..os.date("%Y-%m-%d %H:%M",os.time()).."` `("..progressCurrent.."/"..progressDesired..")`")
						end
					end

					newTaskStr = newTaskStr:gsub("%([0-9]+/[0-9]+%)", "(0/"..progressDesired..")")

				--if there is no progress indicator
				else
					if action == "cancel" then
						fileLines = common.addItemToLogbook(fileLines, itemLineNum, "- CANCELLED: `"..os.date("%Y-%m-%d %H:%M",os.time()).."`")
					else
						fileLines = common.addItemToLogbook(fileLines, itemLineNum, "- DONE: `"..os.date("%Y-%m-%d %H:%M",os.time()).."`")
					end
				end

                --if the repeat indicator is on the Scheduled property
                if scheduled and parsedScheduled["nextUnixTime"] then
                    fileLines = common.addPropertyToItem(fileLines, itemLineNum, "Scheduled", parsedScheduled["nextTimeStr"])

                --if the repeat indicator is on the Deadline property
                elseif deadline and parsedDeadline["nextUnixTime"] then
                    fileLines = common.addPropertyToItem(fileLines, itemLineNum, "Deadline", parsedDeadline["nextTimeStr"])
                end

                fileLines[itemLineNum] = newTaskStr
				--if its the check action, save the last repeat property to the logbook.
				if action ~= "cancel" then
					fileLines = common.addPropertyToItem(fileLines, itemLineNum, "Last Repeat", os.date("%Y-%m-%d %H:%M", currentTime))
				end
            end

        ---------------------DONE/DUE/INFO/CANCELLED---------------------
        elseif taskType=="DONE" then
            print("Can't check a done task.")
            return
        elseif taskType=="DUE" then
            print("Can't check a due task.")
            return
        elseif taskType=="INFO" then
            print("Cant check an info item.")
            return
        elseif taskType=="CANCELLED" then
            print("Can't check a non-task item.")
            return
        end

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
    end
end

return ta
