local common = require("md-agenda.common")

local vim = vim

----------------CHECK TASK-------------
--set comletion time property
local function checkTask()
    local currentBuf = vim.api.nvim_get_current_buf()
    local currentBufLines = vim.api.nvim_buf_get_lines(currentBuf, 0, -1, true)

    local lineNum = vim.api.nvim_win_get_cursor(0)[1]
    local lineContent = vim.fn.getline(lineNum)

    local taskType = lineContent:match("^ *#+ ([A-Z]+): .*$")
    if taskType then

        if taskType~="TODO" and taskType~="HABIT" and taskType~="DONE" and taskType~="DUE" and taskType~="INFO" then
            print("Not a task or has not a supported task type")
            return
        end

        local currentTime = os.time()

        local taskProperties = common.getTaskProperties(currentBufLines, lineNum)

        local scheduledTimeStr, parsedScheduled
        local scheduled=taskProperties["Scheduled"]
        if scheduled then
            scheduledTimeStr = scheduled[2]
            parsedScheduled = common.parseTaskTime(scheduledTimeStr)

            if not parsedScheduled then print("for some reason, scheduled could not correctly parsed") return end

            if currentTime < parsedScheduled["unixTime"] then
                print("Cannot check the task. The scheduled time is not been arrived yet")
                return
            end
        end

        if type=="HABIT" and (not scheduled) then
            print("Cannot check the task. Habits must include a Scheduled property")
            return
        end

        local deadlineTimeStr, parsedDeadline
        local deadline=taskProperties["Deadline"]
        if deadline then
            deadlineTimeStr = deadline[2]
            parsedDeadline = common.parseTaskTime(deadlineTimeStr)

            if not parsedDeadline then print("for some reason, deadline could not correctly parsed") return end
        end

        if deadline and scheduled and parsedDeadline["nextUnixTime"] and parsedScheduled["nextUnixTime"] then
            print("Only one property can contain a repeat indicator.")
            return
        end

        ---------------------TODO/HABIT CASE---------------------
        if taskType=="TODO" or taskType=="HABIT" then

            local newTaskStr = lineContent

            --/IF ITS A NON-REPEATING TASK/--
            if (deadline and not parsedDeadline["nextUnixTime"]) or (scheduled and not parsedScheduled["nextUnixTime"]) or
            (not scheduled and not deadline) then
                newTaskStr = newTaskStr:gsub("TODO:","DONE:"):gsub("HABIT:","DONE:")

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
                    newTaskStr = newTaskStr:gsub("TODO:","DUE:"):gsub("HABIT:","DUE:")
                    return
                --if the repeat indicator on Scheduled property, and the next scheduled time exceeds the deadline
                elseif deadline and scheduled and parsedScheduled["nextUnixTime"] and
                parsedScheduled["nextUnixTime"] > parsedDeadline["unixTime"] then
                    newTaskStr = newTaskStr:gsub("TODO:","DONE:"):gsub("HABIT:","DONE:")
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

        ---------------------DONE/DUE CASE---------------------
        elseif taskType=="DONE" then
            print("Cannot check the task. It is already done. Congratulations!")
            return
        elseif taskType=="DUE" then
            print("Cannot check the task. It is already due. Do better next time.")
            return
        elseif taskType=="INFO" then
            print("Info agenda items cannot be checked.")
            return
        end

        ---
    end
end

--change this to a command
vim.api.nvim_create_user_command('CheckTask', checkTask, {})
