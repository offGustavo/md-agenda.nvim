local common = require("md-agenda.common")

local vim = vim

--------------SET SCHEDULE/DEADLINE VIA CALENDAR--------------
-- Function to generate an array of dates
local function generateDateList()
    local dateList = {}
    local today = os.time() -- Get the current time

    local weekdays = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}

    local months = {
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
    }

    for i = 0, 365 do
        local currentDate = os.date("*t", today + (i * common.oneDay)) -- Get the date for today + i days
        table.insert(dateList, {
            year = currentDate.year,
            month = string.format("%02d", currentDate.month),
            monthName = months[currentDate.month],
            day = string.format("%02d", currentDate.day),
            weekday=weekdays[currentDate.wday]
        })
    end

    return dateList
end

local datePickerItems = {}
local function initializeDatePickerItems()
    if #datePickerItems == 0 then
        datePickerItems = generateDateList()
    end
end

--insertType: scheduled or deadline
local function datePicker(insertType)

    local telescopePickers = require('telescope.pickers')
    local telescopeFinders = require('telescope.finders')
    local telescopeActions = require('telescope.actions')
    local telescopeState = require('telescope.actions.state')
    local telescopeConf = require("telescope.config").values

    local lineNum = vim.api.nvim_win_get_cursor(0)[1]
    local lineContent = vim.fn.getline(lineNum)

    local taskType = lineContent:match("^#+ ([A-Z]+): .*")
    if not (taskType=="TODO" or taskType=="HABIT" or taskType=="DONE" or taskType=="DUE" or taskType=="INFO" or taskType=="CANCELLED") then
        print("Cannot open the date picker. The cursor is not on a task headline")
        return
    end

    initializeDatePickerItems()

    -- Use Telescope to select a suggestion
    telescopePickers.new({}, {
        prompt_title = "Select A Date",
        finder = telescopeFinders.new_table {
            results = datePickerItems,
            entry_maker = function(entry)
                local value = entry.year.."-"..entry.month.."-"..entry.day.." 00:00"
                local display = entry.weekday ..", ".. entry.day.." "..entry.monthName.." ("..entry.month..") "..entry.year
                return {
                    value = value,
                    display = display,
                    ordinal = display
                }
            end,
        },
        sorter = telescopeConf.file_sorter(),
        attach_mappings = function(prompt_bufnr, map)
            telescopeActions.select_default:replace(function()
                telescopeActions.close(prompt_bufnr)
                local selection = telescopeState.get_selected_entry()

                if selection then
                    if insertType=="scheduled" then
                        common.addPropertyToBufTask(lineNum, "Scheduled", selection.value)

                    elseif insertType=="deadline" then
                        common.addPropertyToBufTask(lineNum, "Deadline", selection.value)
                    end
                end
            end)
            return true
        end,
    }):find()
end
vim.api.nvim_create_user_command('TaskScheduled', function()datePicker("scheduled")end, {})
vim.api.nvim_create_user_command('TaskDeadline', function()datePicker("deadline")end, {})
