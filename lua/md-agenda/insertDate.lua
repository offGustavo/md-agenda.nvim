local common = require("md-agenda.common")

local config = require("md-agenda.config")

local vim = vim

local insertDate = {}

local function getDates(startTimeUnix, endTimeUnix)
    local currentDateTable = os.date("*t")
    -- Set hours, minutes, and seconds to zero
    currentDateTable.hour, currentDateTable.min, currentDateTable.sec = 0, 0, 0
    --
    local dates = {}

    local i = 0
    while true do
        if startTimeUnix + (i * common.oneDay) > endTimeUnix then
            break
        end

        local nextDate = os.date("%Y-%m-%d %H:%M", startTimeUnix + (i * common.oneDay)) -- Get the date for today + i days
        table.insert(dates,nextDate)
        i=i+1
    end

    return dates
end

local agendaItemlineNum, agendaItemlineContent

local pageItemCount = 15
local relativePage = 0
local lineNumValue = {}
--insertType: deadline or scheduled
local function renderDateSelector(insertType)

    if not agendaItemlineContent:match("^ *#+ [A-Z]+: .*$") then
        print("You need to place your cursor to the task to add a deadline or scheduled property to it.")
        return
    end

    --The Below code is about date selector buffer

    vim.cmd("new")

    local bufNumber = vim.api.nvim_get_current_buf()

    vim.cmd("highlight bufTitle guifg="..config.config.titleColor.." ctermfg="..config.config.titleColor)
    vim.cmd("syntax match bufTitle /^- .*$/")

    local renderLines = {}
    table.insert(renderLines, "Date Selector - Page: "..relativePage)

    -- Get the current date and time
    local currentDateTable = os.date("*t")
    local currentDateStr = currentDateTable.year.."-"..string.format("%02d", currentDateTable.month).."-"..string.format("%02d", currentDateTable.day)

    -- Set hours, minutes, and seconds to zero
    currentDateTable.hour, currentDateTable.min, currentDateTable.sec = 0, 0, 0
    -- Convert the table back to a timestamp
    local currentDayStart = os.time(currentDateTable)

    --add some comments here, how pagination works can be easily forgotten
    --pagination
    local pageStart = currentDayStart + common.oneDay * pageItemCount * relativePage
    local pageEnd = pageStart + common.oneDay * (pageItemCount - 1)

    local dates = getDates(pageStart, pageEnd)

    lineNumValue = {}
    for i,dateStr in ipairs(dates) do

        --Increase i by 1 to skip the buffer title
        lineNumValue[i+1] = dateStr

        --format date for better readability
        local year,month,day=dateStr:match("([0-9]+)-([0-9]+)-([0-9]+)")
        local taskTimeTable = {
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = 0, min = 0, sec = 0,
            isdst = false  -- daylight saving time flag
        }
        local dayUnixTime = os.time(taskTimeTable)
        local humanDate = os.date("%d %B(%m) %Y - %A",dayUnixTime)

        if currentDateStr == year.."-"..month.."-"..day then
            table.insert(renderLines, "- (Today) "..humanDate)
        else
            table.insert(renderLines, "- "..humanDate)
        end

    end

    vim.api.nvim_buf_set_lines(0, 0, -1, false, renderLines)

    --disable modifying
    vim.api.nvim_buf_set_option(bufNumber, "readonly", true)
    vim.api.nvim_buf_set_option(bufNumber, "modifiable", false)
    vim.api.nvim_buf_set_option(bufNumber, "modified", false)

    vim.keymap.set('n', '<CR>', function()
        local dsLineNum = vim.api.nvim_win_get_cursor(0)[1]
        if dsLineNum==1 then
            print("Please select a date by placing your cursor on the top of it.")
            return
        end

        if insertType=="scheduled" then
            vim.cmd("bd")
            common.addPropertyToBufTask(agendaItemlineNum, "Scheduled", lineNumValue[dsLineNum])

        elseif insertType=="deadline" then
            vim.cmd("bd")
            common.addPropertyToBufTask(agendaItemlineNum, "Deadline", lineNumValue[dsLineNum])
        end
    end, { buffer = bufNumber, noremap = true, silent = true })

    vim.keymap.set('n', '<Right>', function()
        relativePage=relativePage+1
        vim.cmd('bd')
        renderDateSelector(insertType)
    end, { buffer = bufNumber, noremap = true, silent = true })

    vim.keymap.set('n', '<Left>', function()
        relativePage=relativePage-1
        vim.cmd('bd')
        renderDateSelector(insertType)
    end, { buffer = bufNumber, noremap = true, silent = true })
end

insertDate.dateSelector = function(insertType)
    agendaItemlineNum = vim.api.nvim_win_get_cursor(0)[1]
    agendaItemlineContent = vim.fn.getline(agendaItemlineNum)
    relativePage = 0
    renderDateSelector(insertType)
end

return insertDate
