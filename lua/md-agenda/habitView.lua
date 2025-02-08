local config = require("md-agenda.config")

local common = require("md-agenda.common")

local vim = vim

local habitView = {}

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

    local agendaItems = common.getAgendaItems("")

    for _, agendaItem in ipairs(agendaItems) do
        if agendaItem.agendaItem[1] == "HABIT" then

            local habitDays = {}
            --copy days template map's values to this habit's days table
            for k, v in pairs(days) do
                habitDays[k] = v  -- Copy each key-value pair
            end

            ------------------
            local parsedScheduled
            if agendaItem.properties["Scheduled"] then
                parsedScheduled = common.parseTaskTime(agendaItem.properties["Scheduled"])

                if not parsedScheduled then print("for some reason, scheduled could not correctly parsed") return {} end
            end

            local parsedDeadline
            if agendaItem.properties["Deadline"] then
                parsedDeadline = common.parseTaskTime(agendaItem.properties["Deadline"])

                if not parsedDeadline then print("for some reason, deadline could not correctly parsed") return {} end
            end
            ------------------

            --handle with free days between scheduled times based on intervals (repeat indicator)
            if parsedScheduled then
                for _, sortedDate in ipairs(sortedDates) do
                    if not common.IsDateInRangeOfGivenRepeatingTimeStr(agendaItem.properties["Scheduled"], sortedDate) then
                        habitDays[sortedDate]="⍣"
                    end
                end
            end

            --insert logbook tasks to the days
            --as its not an array but map, we use pairs() instead of ipairs()
            for habitDay,log in pairs(agendaItem.logbookItems) do
                if habitDays[habitDay] then
                    local habitStatus = log[1]

                    if habitStatus == "x" then
                        habitDays[habitDay] = "⊹" --it means that the habit is done that day
                    elseif habitStatus == " " then
                        habitDays[habitDay] = "¤" --it means that a progress has been made but habit goal could not be made
                    end
                end
            end

            if agendaItem.properties["Scheduled"] then
                local scheduledDate=agendaItem.properties["Scheduled"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
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

            if agendaItem.properties["Deadline"] then
                local deadlineDate=agendaItem.properties["Deadline"]:match("([0-9]+%-[0-9]+%-[0-9]+)")
                if days[deadlineDate] then
                    habitDays[deadlineDate]="♆" --it means that its the day of the end of the habit
                end
            end

            --habits={ {habit="do bla bla bla", days={2024-04-20="-", 2024-04-21="+", ...}}, ...}
            table.insert(habits, {habit=agendaItem.agendaItem[2], days=habitDays})
        end
    end

    return {sortedDates, habits}
end

--type is habit or agenda
habitView.renderHabitView = function()
    vim.cmd("new")

    local bufNumber = vim.api.nvim_get_current_buf()

    vim.cmd("highlight progressmade guibg="..config.config.habitProgressColor.." ctermbg="..config.config.habitProgressColor.." guifg="..config.config.habitProgressColor.." ctermfg="..config.config.habitProgressColor)
    vim.cmd("syntax match progressmade /¤/")

    vim.cmd("highlight mustdone guibg="..config.config.habitScheduledColor.." ctermbg="..config.config.habitScheduledColor.." guifg="..config.config.habitScheduledColor.." ctermfg="..config.config.habitScheduledColor)
    vim.cmd("syntax match mustdone /♁/")

    vim.cmd("highlight pastscheduled guibg="..config.config.habitPastScheduledColor.." ctermbg="..config.config.habitPastScheduledColor.." guifg="..config.config.habitPastScheduledColor.." ctermfg="..config.config.habitPastScheduledColor)
    vim.cmd("syntax match pastscheduled /⚨/")

    vim.cmd("highlight habitdone guibg="..config.config.habitDoneColor.." ctermbg="..config.config.habitDoneColor.." guifg="..config.config.habitDoneColor.." ctermfg="..config.config.habitDoneColor)
    vim.cmd("syntax match habitdone /⊹/")

    vim.cmd("highlight notdone guibg="..config.config.habitNotDoneColor.." ctermbg="..config.config.habitNotDoneColor.." guifg="..config.config.habitNotDoneColor.." ctermfg="..config.config.habitNotDoneColor)
    vim.cmd("syntax match notdone /ø/")

    vim.cmd("highlight end guibg="..config.config.habitDeadlineColor.." ctermbg="..config.config.habitDeadlineColor.." guifg="..config.config.habitDeadlineColor.." ctermfg="..config.config.habitDeadlineColor)
    vim.cmd("syntax match end /♆/")

    vim.cmd("highlight noneed guibg="..config.config.habitFreeTimeColor.." ctermbg="..config.config.habitFreeTimeColor.." guifg="..config.config.habitFreeTimeColor.." ctermfg="..config.config.habitFreeTimeColor)
    vim.cmd("syntax match noneed /⍣/")

    vim.cmd("highlight today guibg=brown ctermbg=brown guifg=brown ctermfg=brown")
    vim.cmd("syntax match today /♅/")

    vim.cmd("highlight tag guifg="..config.config.tagColor.." ctermfg="..config.config.tagColor)
    vim.cmd("syntax match tag /\\#[a-zA-Z0-9]\\+/")
    vim.cmd("syntax match tag /:[a-zA-Z0-9:]\\+:/")

    local renderLines = {}

    local currentDateTable = os.date("*t")
    -- Set hours, minutes, and seconds to zero
    currentDateTable.hour, currentDateTable.min, currentDateTable.sec = 0, 0, 0
    local currentDayStart = os.time(currentDateTable)
    local currentDateStr = os.date("%Y-%m-%d", currentDayStart)

    --{sortedDates, habits}
    local dayNHabits = getHabitTasks(currentDayStart-common.oneDay*config.config.habitViewPastItems, currentDayStart+common.oneDay*config.config.habitViewFutureItems)

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
        table.insert(renderLines, habit.habit.." :")

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

    vim.keymap.set('n', '<Esc>', function()vim.cmd('bd')
    end, { buffer = bufNumber, noremap = true, silent = true })
end

return habitView
