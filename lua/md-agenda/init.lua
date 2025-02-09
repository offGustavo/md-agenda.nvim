local vim = vim

local function setup(opts)
    local config = require("md-agenda.config").initConfig(opts)

    local common = require("md-agenda.common")

    local insertDate = require("md-agenda.insertDate")
    local checkTask = require("md-agenda.checkTask")
    local agendaView = require("md-agenda.agendaView")
    local habitView = require("md-agenda.habitView")
    local agendaDashboard = require("md-agenda.agendaDashboard")

    --Date Picker
    vim.api.nvim_create_user_command('TaskScheduled', function()insertDate.dateSelector("scheduled")end, {})
    vim.api.nvim_create_user_command('TaskDeadline', function()insertDate.dateSelector("deadline")end, {})

    --Agenda View
    vim.api.nvim_create_user_command('AgendaView',agendaView.agendaView, {})
    vim.api.nvim_create_user_command('AgendaViewWTF', function(avOpts)agendaView.agendaViewWTF(avOpts)end, {nargs = '*'})
    vim.api.nvim_create_user_command('NextAgendaPage', agendaView.nextAgendaPage, {}) -- deprecated
    vim.api.nvim_create_user_command('PrevAgendaPage', agendaView.prevAgendaPage, {}) -- deprecated

    --Habit View
    vim.api.nvim_create_user_command('HabitView', habitView.renderHabitView, {})

    --Agenda Dashboard
    vim.api.nvim_create_user_command('AgendaDashboard', agendaDashboard.renderAgendaDashboard, {})

    --Clear all highlight for all files
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "*",
        callback = function()
            for _,m in ipairs(vim.fn.getmatches()) do
                if m.group == "todoType" or
                m.group == "habitType" or
                m.group == "doneType" or
                m.group == "dueType" or
                m.group == "infoType" or
                m.group == "cancelledTask" or
                m.group == "tag" or common.isTodoItem(m.group) then
                    vim.fn.matchdelete(m.id)
                end
            end
        end,
    })


    vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()

            vim.opt.foldmethod="marker"
            vim.opt.foldmarker = config.config.foldmarker

            --Check Task -- (Modify the current buffer and the current line in markdown documents. This changes in the view buffers.)
            vim.api.nvim_buf_create_user_command(0, 'CheckTask', function()
                local currentBufNum = vim.api.nvim_get_current_buf()
                checkTask.taskAction(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], "check", currentBufNum)
            end, {})
            vim.api.nvim_buf_create_user_command(0, 'CancelTask', function()
                local currentBufNum = vim.api.nvim_get_current_buf()
                checkTask.taskAction(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], "cancel", currentBufNum)
            end, {})

            --Re-highlight for the markdown files
            vim.cmd("highlight todoType guifg="..config.config.todoTypeColor.." ctermfg="..config.config.todoTypeColor)
            vim.cmd("call matchadd('todoType', 'TODO')")

            vim.cmd("highlight habitType guifg="..config.config.habitTypeColor.." ctermfg="..config.config.habitTypeColor)
            vim.cmd("call matchadd('habitType','HABIT')")

            vim.cmd("highlight dueType guifg="..config.config.dueTypeColor.." ctermfg="..config.config.dueTypeColor)
            vim.cmd("call matchadd('dueType','DUE')")

            vim.cmd("highlight doneType guifg="..config.config.doneTypeColor.." ctermfg="..config.config.doneTypeColor)
            vim.cmd("call matchadd('doneType','DONE')")

            vim.cmd("highlight infoType guifg="..config.config.infoTypeColor.." ctermfg="..config.config.infoTypeColor)
            vim.cmd("call matchadd('infoType','INFO')")

            vim.cmd("highlight cancelledTask guifg="..config.config.cancelledTypeColor.." ctermfg="..config.config.cancelledTypeColor)
            vim.cmd("call matchadd('cancelledTask','CANCELLED')")

            vim.cmd("highlight tag guifg="..config.config.tagColor.." ctermfg="..config.config.tagColor)
            vim.cmd("call matchadd('tag','\\#[a-zA-Z0-9]\\+')")
            vim.cmd("call matchadd('tag',':[a-zA-Z0-9:]\\+:')")

            for customType, itsColor in pairs(config.config.customTodoTypes) do
                vim.cmd("highlight "..customType.." guifg="..itsColor.." ctermfg="..itsColor)
                vim.cmd("call matchadd('"..customType.."', '"..customType.."')")
            end
        end,
    })

end

return {setup = setup}
