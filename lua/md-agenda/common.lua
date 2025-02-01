--functions and variables that are used in multiple files
M = {}

local vim = vim

-----------VARS--------------
M.oneDay = 24*60*60 --one day in seconds
M.config = {}

------------GET MAP ITEM COUNT--------------
M.getMapItemCount = function(map)
    local count = 0
    for _, _ in pairs(map) do
        count = count + 1
    end
    return count
end

M.splitFoldmarkerString = function()
    local result = {}
    for item in string.gmatch(M.config.foldmarker, "([^,]+)") do
        table.insert(result, item)
    end
    return result
end


local function isDirectory(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == 'directory'
end

local cachePath = vim.fn.stdpath("data").."/md-agenda"
M.saveRemoteAgendaFiles = function()
    for _,agendaFilePath in ipairs(M.config.agendaFiles) do
        local fileName = agendaFilePath:match("^[a-z]+://.+/(.+%.md)$")
        if fileName then
            local command = string.format("curl -s --fail %s", agendaFilePath)
            local body = vim.fn.system(command)
            local code = vim.v.shell_error

            if not body or code ~= 0 then
                print("Failed to get remote "..fileName)
                goto continue
            end

            --save file to the cache folder
            if not isDirectory(cachePath) then
                -- Directory does not exist, create it
                local success, err = vim.loop.fs_mkdir(cachePath, 511) -- 511 is the permission (755 in octal)
                if not success then
                    print("Error creating directory: " .. err)
                    goto continue
                end
            end

            local f = assert(io.open(cachePath.."/"..fileName, 'wb'))
            f:write(body)
            f:close()
        end
        ::continue::
    end
end

M.listAgendaFiles = function()
    local agendaFiles = {}
    for _,agendaFilePath in ipairs(M.config.agendaFiles) do

        --if its an url that contains markdown file
        local fileName = agendaFilePath:match("^[a-z]+://.+/(.+%.md)$")
        if fileName then
            local filePath = cachePath.."/"..fileName
            local fileStats = vim.loop.fs_stat(filePath)
            if fileStats and fileStats.type == "file" then
                table.insert(agendaFiles, filePath)
            end

        --if its a local file
        else
            agendaFilePath = vim.fn.expand(agendaFilePath)

            if isDirectory(agendaFilePath) then
                local fileList = vim.fn.systemlist("rg --files --glob '!.*' --glob '*.md' " .. agendaFilePath)
                for _,oneFile in ipairs(fileList) do
                    table.insert(agendaFiles, oneFile)
                end
            else
                table.insert(agendaFiles, agendaFilePath)
            end
        end
    end

    return agendaFiles
end

M.parseTaskTime = function(timeString)
--\{{{
    --time string's format: 2025-12-30 18:05 +1d (the last one is the repeat interval and is optional)
    local taskTimeMap = {}

    local year,month,day=timeString:match("([0-9]+)-([0-9]+)-([0-9]+)")
    local hour,minute=timeString:match("([0-9]+):([0-9]+)")
    if (not hour) and (not minute) then
        hour = "0"
        minute = "0"
    end

    local taskTimeTable = {
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(minute),
        sec = 0,  -- seconds can be set to 0
        isdst = false  -- daylight saving time flag
    }
    local taskUnixTime = os.time(taskTimeTable)
    taskTimeMap["unixTime"]=taskUnixTime
    --Seconds since task date's day start. Subtract to get task date's day start (00:00)
    local sinceTaskTimeDayStart = 60*taskTimeTable.min*taskTimeTable.hour

    local currentUnixTime = os.time()
    local currentTimeTable = os.date("*t", currentUnixTime)

    --make it day start
    currentTimeTable.hour, currentTimeTable.min, currentTimeTable.sec = 0,0,0

    --repeat indicator's format: ++12d, +3w, .+1m etc.
    local repeatType, repeatNum, repeatInterval = timeString:match(" ([%.%+]+)([0-9]+)([a-z])")

    if repeatType and repeatNum and repeatInterval then

        if repeatType ~= "+" and repeatType ~= "++" and repeatType ~= ".+" then
            print("invalid repeat type. You can only use '+', '++' and '.+'")
            return
        end

        taskTimeMap["repeatType"] = repeatType

        if repeatInterval ~= "d" and repeatInterval ~= "w" and repeatInterval ~= "m" and repeatInterval ~= "y" then
            print("invalid repeat interval. You can only use d(day), w(week), m(month) and y(year)")
            return
        end

        local num = tonumber(repeatNum)

        if num <= 0 then
            print("repeat indicator number cannot be zero or less than zero")
            return taskTimeMap
        end

        --"+"
        if repeatType=="+" then
            --day
            if repeatInterval=="d" then
                taskTimeTable.day=taskTimeTable.day+num
                taskTimeMap["nextUnixTime"] = os.time(taskTimeTable) - sinceTaskTimeDayStart

            --week
            elseif repeatInterval=="w" then
                taskTimeTable.day=taskTimeTable.day+7*num
                taskTimeMap["nextUnixTime"] = os.time(taskTimeTable) - sinceTaskTimeDayStart

            --month
            elseif repeatInterval=="m" then
                taskTimeTable.month = taskTimeTable.month + num
                taskTimeMap["nextUnixTime"] = os.time(taskTimeTable) - sinceTaskTimeDayStart

            --year
            elseif repeatInterval=="y" then
                taskTimeTable.year = taskTimeTable.year + num
                taskTimeMap["nextUnixTime"] = os.time(taskTimeTable) - sinceTaskTimeDayStart
            end

        --"++"
        elseif repeatType=="++" then
            taskTimeTable.hour, taskTimeTable.min = 0,0
            --day
            if repeatInterval=="d" then
                taskTimeTable.day=taskTimeTable.day+num
                taskTimeMap["nextUnixTime"] = os.time(taskTimeTable) - sinceTaskTimeDayStart

            --week
            elseif repeatInterval=="w" then
                taskTimeTable.day=taskTimeTable.day+7*num
                taskTimeMap["nextUnixTime"] = os.time(taskTimeTable) - sinceTaskTimeDayStart

            --month
            elseif repeatInterval=="m" then
                taskTimeTable.month = taskTimeTable.month + num
                taskTimeMap["nextUnixTime"] = os.time(taskTimeTable) - sinceTaskTimeDayStart

            --year
            elseif repeatInterval=="y" then
                taskTimeTable.year = taskTimeTable.year + num
                taskTimeMap["nextUnixTime"] = os.time(taskTimeTable) - sinceTaskTimeDayStart
            end

            --increase the nextUnixTime until it shows a future time
            if taskTimeMap["nextUnixTime"] < os.time(currentTimeTable) then
                while true do
                    local nextUnixTime = taskTimeMap["nextUnixTime"] + M.oneDay
                    taskTimeMap["nextUnixTime"] = nextUnixTime

                    if os.time(currentTimeTable) < taskTimeMap["nextUnixTime"] then
                        if repeatInterval=="d" then
                            break

                        elseif repeatInterval=="w" then
                            if os.date("*t",os.time(taskTimeTable)).wday == os.date("*t",nextUnixTime).wday then
                                break
                            end

                        elseif repeatInterval=="m" then
                            if taskTimeTable.day == os.date("*t",nextUnixTime).day then
                                break
                            end

                        elseif repeatInterval=="y" then
                            if taskTimeTable.year == os.date("*t",nextUnixTime).year then
                                break
                            end
                        end
                    end
                end
            end

        --".+"
        elseif repeatType==".+" then
            --day
            if repeatInterval=="d" then
                currentTimeTable.day=currentTimeTable.day+num
                taskTimeMap["nextUnixTime"] = os.time(currentTimeTable)
                --as you may know from the elementary school, if we just subtract num, we arrive today.
                --We subtract num*2 to go to the previous time
                currentTimeTable.day=currentTimeTable.day-num*2
                taskTimeMap["pastUnixTime"] = os.time(currentTimeTable)

                taskTimeMap["intervalInDays"]=num

                --this derived from the task date instead of current date
                --TODO: deprecated, use in ++ or +
                taskTimeTable.day=taskTimeTable.day+num
                taskTimeMap["nextTaskUnixTime"] = os.time(taskTimeTable)

            --week
            elseif repeatInterval=="w" then
                currentTimeTable.day=currentTimeTable.day+7*num
                taskTimeMap["nextUnixTime"] = os.time(currentTimeTable)
                --newTimeTable.day=newTimeTable.day-7*num*2
                --taskTimeMap["pastUnixTime"] = os.time(newTimeTable)

                taskTimeMap["intervalInDays"]=7*num

                --this derived from the task date instead of current date
                --TODO: deprecated, use in ++ or +
                taskTimeTable.day=taskTimeTable.day+7*num
                taskTimeMap["nextTaskUnixTime"] = os.time(taskTimeTable)

            elseif repeatInterval=="m" then
                currentTimeTable.month = currentTimeTable.month + num
                taskTimeMap["nextUnixTime"] = os.time(currentTimeTable)

            elseif repeatInterval=="y" then
                currentTimeTable.year = currentTimeTable.year + num
                taskTimeMap["nextUnixTime"] = os.time(currentTimeTable)
            end
        end

        taskTimeMap["nextTimeStr"] = os.date("%Y-%m-%d %H:%M", taskTimeMap["nextUnixTime"]) .." +"..repeatNum..repeatInterval
        taskTimeMap["nextTaskTimeStr"] = os.date("%Y-%m-%d %H:%M", taskTimeMap["nextTaskUnixTime"]) .." +"..repeatNum..repeatInterval
        --taskTimeMap["pastTimeStr"] = os.date("%Y-%m-%d %H:%M", taskTimeMap["pastUnixTime"]) .." +"..repeatNum..repeatInterval
    end

    return taskTimeMap
--\}}}
end

--Checks if the given date is in the range of the given task time string
--wantedDateStr's format: 2000-12-30
--if returned value is false, it means that date is a free time
M.IsDateInRangeOfGivenRepeatingTimeStr = function(repeatingTimeStr, wantedDateStr)
    local ryear,rmonth,rday=repeatingTimeStr:match("([0-9]+)-([0-9]+)-([0-9]+)")

    local repeatingTimeTable = {
        year = tonumber(ryear),
        month = tonumber(rmonth),
        day = tonumber(rday),
        isdst = false  -- daylight saving time flag
    }
    local repeatingTimeUnix = os.time(repeatingTimeTable)

    local wyear,wmonth,wday=wantedDateStr:match("([0-9]+)-([0-9]+)-([0-9]+)")
    local wantedDateTable = {
        year = tonumber(wyear),
        month = tonumber(wmonth),
        day = tonumber(wday),
        isdst = false
    }
    local wantedDateUnix = os.time(wantedDateTable)

    local repeatType, repeatNumStr, repeatInterval = repeatingTimeStr:match(" ([%.%+]+)([0-9]+)([a-z])")
    if repeatType and repeatNumStr and repeatInterval then

        local repeatNum = tonumber(repeatNumStr)

        -------------------

        if repeatType ~= "+" and repeatType ~= "++" and repeatType ~= ".+" then
            print("invalid repeat type. You can only use '+', '++' and '.+'")
            return false
        end
        if repeatInterval ~= "d" and repeatInterval ~= "w" and repeatInterval ~= "m" and repeatInterval ~= "y" then
            print("invalid repeat interval. You can only use d(day), w(week), m(month) and y(year)")
            return false
        end

        local num = tonumber(repeatNum)

        if num <= 0 then
            print("repeat indicator number cannot be zero or less than zero")
            return false
        end

        --------------------

        if repeatInterval == "y" then
            if repeatingTimeTable.month == wantedDateTable.month and
            repeatingTimeTable.day == wantedDateTable.day then
                return true

            else return false end

        elseif repeatInterval == "m" then
            if repeatingTimeTable.day == wantedDateTable.day then
                return true

            else return false end

        elseif repeatInterval == "w" then
            if os.date("*t",repeatingTimeUnix).wday == os.date("*t",wantedDateUnix) then
                return true

            else return false end

        elseif repeatInterval == "d" then
            --days since epoch
            local repeatingTimeDSE = math.floor(repeatingTimeUnix / M.oneDay)
            local wantedDateDSE = math.floor(wantedDateUnix / M.oneDay)

            --this formula means that we can eventually arrive to wantedDate from repeatingTime if we add or subtract repeatNum 
            if (wantedDateDSE - repeatingTimeDSE) % repeatNum == 0 then
                return true

            else return false end
        end

    else
        print("Given date is not a repeating task")
        return false
    end
end

-------------GET TASK PROPERTIES-------------
-- its not just for current buffer but all files. So we use content lines array instead
M.getTaskProperties = function(ContentLinesArr, taskLineNum)
    local properities = {}

    local propertyLineNum = taskLineNum + 1

    local currentLine = 0
    for _,line in ipairs(ContentLinesArr) do
        currentLine = currentLine + 1

        if currentLine < propertyLineNum then
            goto continue
        end

        local propertyPattern = "^ *- (.+): `(.*)`"

        local key,value = line:match(propertyPattern)
        if key and value then
            properities[key]={propertyLineNum, value}

            propertyLineNum=propertyLineNum+1

            --print("Property: "..key.." "..value)
        else
          break
        end

        ::continue::
    end

    return properities
end

-------------ADD A PROPERTY TO A TASK IN THE CURRENT BUFFER-----------------
--add a new property to the task or update the existing one
M.addPropertyToBufTask = function(taskLineNum, key, value)
    local currentBuf = vim.api.nvim_get_current_buf()
    local currentBufLines = vim.api.nvim_buf_get_lines(currentBuf, 0, -1, true)

    local taskProperties = M.getTaskProperties(currentBufLines, taskLineNum)

    --if it exists, update
    if taskProperties[key] then
        local propertyLineNum = taskProperties[key][1]
        vim.api.nvim_buf_set_lines(0, propertyLineNum-1, propertyLineNum, false, { string.format("- %s: `%s`", key, value) })

    --if it does not exist, create
    else
        local newProperty = string.format("- %s: `%s`", key, value)

        table.insert(currentBufLines, taskLineNum+1, newProperty)
        vim.api.nvim_buf_set_lines(currentBuf, 0, -1, false, currentBufLines)
    end
end

--------------SAVE TO THE LOGBOOK---------------
M.saveToLogbook = function(taskLineNum, logStr)
    local lineNum = taskLineNum+1

    local logbookExists = false
    local logbookStart=0

    local currentBuf = vim.api.nvim_get_current_buf()
    local currentBufLines = vim.api.nvim_buf_get_lines(currentBuf, 0, -1, true)

    --determine if the task has a logbook
    while true do
        local lineContent = vim.fn.getline(lineNum)

        --if reached to another header or end of the file, stop
        if #currentBufLines < lineNum or lineContent:match(" *#+") then
            break
        end

        if lineContent:match(".*<details logbook>") then
            logbookStart = lineNum
            logbookExists = true
            break

        end

        lineNum=lineNum+1
    end

    if logbookExists then
        --there must be a line space between <details logbook> html tag and markdown. So we put new markdown log to two line under the details tag
        table.insert(currentBufLines, logbookStart+2, "  "..logStr)

    --if logbook does not found, create one and insert the logStr
    else
        --insert below properties
        local properties = M.getTaskProperties(currentBufLines, taskLineNum)
        local propertyCount = M.getMapItemCount(properties)

        local newLines = {}
        table.insert(newLines, "<details logbook><!--"..M.splitFoldmarkerString()[1].."-->")
        table.insert(newLines, "")
        table.insert(newLines, "  "..logStr)
        table.insert(newLines, "<!--"..M.splitFoldmarkerString()[2].."--></details>")

        for i, newLine in ipairs(newLines) do
            table.insert(currentBufLines, taskLineNum + propertyCount + i, newLine)
        end
    end

    vim.api.nvim_buf_set_lines(currentBuf, 0, -1, false, currentBufLines)
end

---------------GET LOGBOOK ENTRIES---------------
M.getLogbookEntries = function(ContentLinesArr, taskLineNum)
    local entries = {}

    local logbookStartPassed = false

    local lineNumber = 0
    for _,line in ipairs(ContentLinesArr) do
        lineNumber = lineNumber+1

        --skip task headline
        if lineNumber < taskLineNum+1 then goto continue end

        if line:match(".*<details logbook>") then
            logbookStartPassed = true
        end

        if logbookStartPassed then
            --example logbook line: - [x] `2022-12-30 18:80` `(6/10)`
            local status, text = line:match(" *- %[(.+)%] (.*)")

            if status and text then
                local log = {}

                table.insert(log, status)

                local time = text:match("`([0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+)`")
                if not time then
                    goto continue
                end

                table.insert(log, time)

                local progressIndicator = text:match("`(%([0-9]+/[0-9]+%))`")
                if progressIndicator then
                    table.insert(log, progressIndicator)
                end

                local date = time:match("([0-9]+-[0-9]+-[0-9]+)")
                entries[date] = log
            end
        end

        --stop when arrived to another header or logbook's end
        if line:match("^#+ .*") or line:match(".*</details>") then
            break
        end
        ::continue::
    end

    return entries
end

return M
