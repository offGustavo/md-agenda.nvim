local common = require("md-agenda.common")

local vim = vim

local ta = {} --task action

---DEPRECATED
ta.checkTask = function(checkAction)
    local currentBuf = vim.api.nvim_get_current_buf()
    local currentBufLines = vim.api.nvim_buf_get_lines(currentBuf, 0, -1, true)

    local lineNum = vim.api.nvim_win_get_cursor(0)[1]
    local lineContent = vim.fn.getline(lineNum)

    local taskType = lineContent:match("^ *#+ ([A-Z]+): .*$")
    if taskType then

        if (not common.isTodoItem(taskType)) and taskType~="HABIT" and taskType~="DONE" and taskType~="DUE" and taskType~="INFO" and taskType~="CANCELLED" then
            print("Not a task or has not a supported task type")
            return
        end

        ---CANCEL ACTION - START
        if common.isTodoItem(taskType) and checkAction == "cancel" then
            local newTaskStr = lineContent:gsub("TODO:","CANCELLED:")
            vim.api.nvim_buf_set_lines(0, lineNum-1, lineNum, false, { newTaskStr })
            return
        elseif (not common.isTodoItem(taskType)) and checkAction == "cancel" then
            print("Can't cancel tasks other than TODO.")
            return
        end
        ---CANCEL ACTION - END

        ---THE REST IS DEFAULT CHECKING ACTION
        local currentTime = os.time()

        local taskProperties = common.getTaskProperties(currentBufLines, lineNum, false)

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
                newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DONE:")

                if deadline and parsedDeadline["unixTime"] < currentTime then
                    newTaskStr = newTaskStr:gsub("DONE:","DUE:")
                end

                --The start line is 0-indexed unlike lua. thus, end line (excluded) is lineNum and changed line is lineNum-1.
                vim.api.nvim_buf_set_lines(0, lineNum-1, lineNum, false, { newTaskStr })
                common.addPropertyToBufTask(lineNum, "Completion", os.date("%Y-%m-%d %H:%M", currentTime))

            ------------------------

            --/IF ITS A REPEATING TASK/--
            elseif (deadline and parsedDeadline["nextUnixTime"]) or (scheduled and parsedScheduled["nextUnixTime"]) then

                --if the repeat indicator on Scheduled property, and current day exceeds the deadline
                if deadline and scheduled and parsedScheduled["nextUnixTime"] and
                currentTime > parsedDeadline["unixTime"] then
                    newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DUE:")
                    return
                --if the repeat indicator on Scheduled property, and the next scheduled time exceeds the deadline
                elseif deadline and scheduled and parsedScheduled["nextUnixTime"] and
                parsedScheduled["nextUnixTime"] > parsedDeadline["unixTime"] then
                    newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DONE:")
                    return
                end

                local progressCurrent, progressDesired = lineContent:match(".*%(([0-9]+)/([0-9]+)%).*")
                --if there is a progress indicator in the task
                if progressCurrent and progressDesired then
                    if tonumber(progressCurrent)==0 then
                        print("Cannot check the task. No progress has been made.")
                        return
                    end

                    --do not mark as done if the progress is not completed
                    if tonumber(progressCurrent) < tonumber(progressDesired) then
                        common.saveToLogbook(lineNum, "- [ ] `"..os.date("%Y-%m-%d %H:%M",os.time()).."` `("..progressCurrent.."/"..progressDesired..")`")
                    else
                        common.saveToLogbook(lineNum, "- [x] `"..os.date("%Y-%m-%d %H:%M",os.time()).."` `("..progressCurrent.."/"..progressDesired..")`")
                    end

                    newTaskStr = newTaskStr:gsub("%([0-9]+/[0-9]+%)", "(0/"..progressDesired..")")

                --if there is no progress indicator
                else
                    common.saveToLogbook(lineNum, "- [x] `"..os.date("%Y-%m-%d %H:%M",os.time()).."`")
                end

                --if the repeat indicator is on the Scheduled property
                if scheduled and parsedScheduled["nextUnixTime"] then
                    common.addPropertyToBufTask(lineNum, "Scheduled", parsedScheduled["nextTimeStr"])
                    --vim.api.nvim_buf_set_lines(0, scheduledLineNum-1, scheduledLineNum, false, { "- Scheduled: `"..parsedScheduled["nextTimeStr"].."`" })

                --if the repeat indicator is on the Deadline property
                elseif deadline and parsedDeadline["nextUnixTime"] then
                    common.addPropertyToBufTask(lineNum, "Deadline", parsedDeadline["nextTimeStr"])
                end

                --The start line is 0-indexed unlike lua. thus, end line (excluded) is lineNum and changed line is lineNum-1.
                vim.api.nvim_buf_set_lines(0, lineNum-1, lineNum, false, { newTaskStr })
                common.addPropertyToBufTask(lineNum, "Last Repeat", os.date("%Y-%m-%d %H:%M", currentTime))
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
    end
end

--action: "cancel" or "check"
ta.taskAction = function(filepath, itemLineNum, action, bufferRefreshNum)
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

        ---CANCEL ACTION - START
        if common.isTodoItem(taskType) and action == "cancel" then
            local newTaskStr = lineContent:gsub("TODO:","CANCELLED:")
            fileLines[itemLineNum] = newTaskStr
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

            return

        elseif (not common.isTodoItem(taskType)) and action == "cancel" then
            print("Can't cancel tasks other than TODO.")
            return
        end
        ---CANCEL ACTION - END

        ---THE REST IS DEFAULT CHECKING ACTION
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
                newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DONE:")

                if deadline and parsedDeadline["unixTime"] < currentTime then
                    newTaskStr = newTaskStr:gsub("DONE:","DUE:")
                end

                --The start line is 0-indexed unlike lua. thus, end line (excluded) is lineNum and changed line is lineNum-1.
                fileLines[itemLineNum] = newTaskStr
                fileLines = common.addPropertyToItem(fileLines, itemLineNum, "Completion", os.date("%Y-%m-%d %H:%M", currentTime))

            ------------------------

            --/IF ITS A REPEATING TASK/--
            elseif (deadline and parsedDeadline["nextUnixTime"]) or (scheduled and parsedScheduled["nextUnixTime"]) then

                --if the repeat indicator on Scheduled property, and current day exceeds the deadline
                if deadline and scheduled and parsedScheduled["nextUnixTime"] and
                currentTime > parsedDeadline["unixTime"] then
                    newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DUE:")
                    return
                --if the repeat indicator on Scheduled property, and the next scheduled time exceeds the deadline
                elseif deadline and scheduled and parsedScheduled["nextUnixTime"] and
                parsedScheduled["nextUnixTime"] > parsedDeadline["unixTime"] then
                    newTaskStr = newTaskStr:gsub("# [A-Z]+:","# DONE:")
                    return
                end

                local progressCurrent, progressDesired = lineContent:match(".*%(([0-9]+)/([0-9]+)%).*")
                --if there is a progress indicator in the task
                if progressCurrent and progressDesired then
                    if tonumber(progressCurrent)==0 then
                        print("Cannot check the task. No progress has been made.")
                        return
                    end

                    --do not mark as done if the progress is not completed
                    if tonumber(progressCurrent) < tonumber(progressDesired) then
                        fileLines = common.addItemToLogbook(fileLines, itemLineNum, "- [ ] `"..os.date("%Y-%m-%d %H:%M",os.time()).."` `("..progressCurrent.."/"..progressDesired..")`")
                    else
                        fileLines = common.addItemToLogbook(fileLines, itemLineNum, "- [x] `"..os.date("%Y-%m-%d %H:%M",os.time()).."` `("..progressCurrent.."/"..progressDesired..")`")
                    end

                    newTaskStr = newTaskStr:gsub("%([0-9]+/[0-9]+%)", "(0/"..progressDesired..")")

                --if there is no progress indicator
                else
                    fileLines = common.addItemToLogbook(fileLines, itemLineNum, "- [x] `"..os.date("%Y-%m-%d %H:%M",os.time()).."`")
                end

                --if the repeat indicator is on the Scheduled property
                if scheduled and parsedScheduled["nextUnixTime"] then
                    fileLines = common.addPropertyToItem(fileLines, itemLineNum, "Scheduled", parsedScheduled["nextTimeStr"])

                --if the repeat indicator is on the Deadline property
                elseif deadline and parsedDeadline["nextUnixTime"] then
                    fileLines = common.addPropertyToItem(fileLines, itemLineNum, "Deadline", parsedDeadline["nextTimeStr"])
                end

                fileLines[itemLineNum] = newTaskStr
                fileLines = common.addPropertyToItem(fileLines, itemLineNum, "Last Repeat", os.date("%Y-%m-%d %H:%M", currentTime))
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
