local common = require("md-agenda.common")

local vim = vim

---------------HABIT VIEW---------------
local function getHabitTasks(startTimeUnix, endTimeUnix)
    local currentDateTable = os.date("*t")
    local currentDateStr = currentDateTable.year.."-"..string.format("%02d", currentDateTable.month).."-"..string.format("%02d", currentDateTable.day)
    -- Set hours, minutes, and seconds to zero
    currentDateTable.hour, currentDateTable.min, currentDateTable.sec = 0, 0, 0
    local currentDayStart = os.time(currentDateTable)

    local sortedDates = {}

    local days = {}
    local i = 0
    while true do
        if startTimeUnix + (i * common.oneDay) > endTimeUnix then
            break
        end

        local nextDate = os.date("%Y-%m-%d", startTimeUnix + (i * common.oneDay)) -- Get the date for today + i days
        days[nextDate]="ø" --it means task is not made

        table.insert(sortedDates,nextDate)
        i=i+1
    end

    --color today as brown
    if days[currentDateStr] then
        days[currentDateStr]="♅" --it means that the day is today
    end

    local habits = {}

    for _,agendaFilePath in ipairs(common.listAgendaFiles()) do
        local file_content = vim.fn.readfile(agendaFilePath)
        if file_content then
            --also get file header
            local lineNumber = 0
            for _,line in ipairs(file_content) do
                lineNumber = lineNumber+1

                local taskType,title = line:match("^#+ (.+): (.*)")
                if (taskType=="HABIT") and title then

                    local taskProperties = common.getTaskProperties(file_content, lineNumber)

                    local logbookItems = common.getLogbookEntries(file_content, lineNumber)

                    local habitDays = {}
                    --copy days template map's values to this habit's days table
                    for k, v in pairs(days) do
                        habitDays[k] = v  -- Copy each key-value pair
                    end

                    --------------------------

                    local scheduledTimeStr, parsedScheduled
                    local scheduled=taskProperties["Scheduled"]
                    if scheduled then
                        scheduledTimeStr = scheduled[2]
                        parsedScheduled = common.parseTaskTime(scheduledTimeStr)

                        if not parsedScheduled then print("for some reason, scheduled could not correctly parsed") return end
                    end

                    local deadlineTimeStr, parsedDeadline
                    local deadline=taskProperties["Deadline"]
                    if deadline then
                        deadlineTimeStr = deadline[2]
                        parsedDeadline = common.parseTaskTime(deadlineTimeStr)

                        if not parsedDeadline then print("for some reason, deadline could not correctly parsed") return end
                    end

                    --------------------------

                    --handle with free days between scheduled times based on intervals (repeat indicator)
                    if parsedScheduled then
                        for _, sortedDate in ipairs(sortedDates) do
                            if not common.IsDateInRangeOfGivenRepeatingTimeStr(scheduledTimeStr, sortedDate) then
                                habitDays[sortedDate]="⍣"
                            end
                        end
                    end

                    --insert logbook tasks to the days
                    --as its not an array but map, we use pairs() instead of ipairs()
                    for habitDay,log in pairs(logbookItems) do
                        if habitDays[habitDay] then
                            local habitStatus = log[1]

                            if habitStatus == "x" then
                                habitDays[habitDay] = "⊹" --it means that the habit is done that day
                            elseif habitStatus == " " then
                                habitDays[habitDay] = "¤" --it means that a progress has been made but habit goal could not be made
                            end
                        end
                    end

                    if scheduled then
                        local scheduledDate=scheduledTimeStr:match("([0-9]+%-[0-9]+%-[0-9]+)")
                        if habitDays[scheduledDate] then

                            --if the task is scheduled in the past, show past schedulation in different color
                            --and color today yellow
                            if parsedScheduled["unixTime"] < currentDayStart then
                                habitDays[scheduledDate]="⚨"
                                habitDays[currentDateStr]="♁"--it means that the habit must be done that day
                            else
                                habitDays[scheduledDate]="♁" --it means that the habit must be done that day
                            end
                        end
                    end

                    if deadline then
                        local deadlineDate=deadlineTimeStr:match("([0-9]+%-[0-9]+%-[0-9]+)")
                        if days[deadlineDate] then
                            habitDays[deadlineDate]="♆" --it means that its the day of the end of the habit
                        end
                    end

                    --habits={ {habit="do bla bla bla", days={2024-04-20="-", 2024-04-21="+", ...}}, ...}
                    table.insert(habits, {habit=title, days=habitDays})
                end
            end
        end
    end

    return {sortedDates, habits}
end

--type is habit or agenda
local function renderHabitView()
    vim.cmd("new")

    local bufNumber = vim.api.nvim_get_current_buf()

    vim.cmd("highlight progressmade guibg=lightgreen ctermbg=lightgreen guifg=lightgreen ctermfg=lightgreen")
    vim.cmd("syntax match progressmade /¤/")

    vim.cmd("highlight mustdone guibg=yellow ctermbg=yellow guifg=yellow ctermfg=yellow")
    vim.cmd("syntax match mustdone /♁/")

    vim.cmd("highlight pastscheduled guibg=darkyellow ctermbg=darkyellow guifg=darkyellow ctermfg=darkyellow")
    vim.cmd("syntax match pastscheduled /⚨/")

    vim.cmd("highlight habitdone guibg=green ctermbg=green guifg=green ctermfg=green")
    vim.cmd("syntax match habitdone /⊹/")

    vim.cmd("highlight notdone guibg=red ctermbg=red guifg=red ctermfg=red")
    vim.cmd("syntax match notdone /ø/")

    vim.cmd("highlight end guibg=gray ctermbg=gray guifg=gray ctermfg=gray")
    vim.cmd("syntax match end /♆/")

    vim.cmd("highlight noneed guibg=blue ctermbg=blue guifg=blue ctermfg=blue")
    vim.cmd("syntax match noneed /⍣/")

    vim.cmd("highlight today guibg=brown ctermbg=brown guifg=brown ctermfg=brown")
    vim.cmd("syntax match today /♅/")

    vim.cmd("highlight tag guifg=blue ctermfg=blue")
    vim.cmd("syntax match tag /\\#[a-zA-Z0-9]\\+/")
    vim.cmd("syntax match tag /:[a-zA-Z0-9:]\\+:/")

    local renderLines = {}

    local currentDateTable = os.date("*t")
    -- Set hours, minutes, and seconds to zero
    currentDateTable.hour, currentDateTable.min, currentDateTable.sec = 0, 0, 0
    local currentDayStart = os.time(currentDateTable)
    local currentDateStr = os.date("%Y-%m-%d", currentDayStart)

    --{sortedDates, habits}
    local dayNHabits = getHabitTasks(currentDayStart-common.oneDay*common.config.habitViewPastItems, currentDayStart+common.oneDay*common.config.habitViewFutureItems)

    --today guide line
    local guideLine = ""
    for _,dateStr in ipairs(dayNHabits[1]) do
        if dateStr == currentDateStr then
            guideLine=guideLine.."v (today)"
            break
        else
            guideLine=guideLine.."-"
        end
    end
    table.insert(renderLines, guideLine)

    --habits
    for _,habit in ipairs(dayNHabits[2]) do
        table.insert(renderLines, habit.habit..":")

        local consistencyGraph = ""
        for _,dateStr in ipairs(dayNHabits[1]) do
            consistencyGraph = consistencyGraph .. habit.days[dateStr]
        end
        table.insert(renderLines, consistencyGraph)
        --table.insert(renderLines, "")
    end

    vim.api.nvim_buf_set_lines(0, 0, -1, false, renderLines)

    --disable modifying
    vim.api.nvim_buf_set_option(bufNumber, "readonly", true)
    vim.api.nvim_buf_set_option(bufNumber, "modifiable", false)
    vim.api.nvim_buf_set_option(bufNumber, "modified", false)
end

vim.api.nvim_create_user_command('HabitView', renderHabitView, {})
