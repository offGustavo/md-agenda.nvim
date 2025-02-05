M = {}

M.setup = function(opts)
    local common = require("md-agenda.common")
    common.config.agendaFiles = opts.agendaFiles or {}
    common.config.agendaViewPageItems = opts.agendaViewPageItems or 10
    common.config.showNonTimeawareTasksToday = opts.showNonTimeawareTasksToday or false

    common.config.remindDeadlineInDays = opts.remindDeadlineInDays or 30
    common.config.remindScheduledInDays = opts.remindScheduledInDays or 10

    common.config.habitViewPastItems = opts.habitViewPastItems or 24
    common.config.habitViewFutureItems = opts.habitViewFutureItems or 3
    common.config.foldmarker = opts.folmarker or "{{{,}}}"

    common.config.customTodoTypes = opts.customTodoTypes or {}

    common.config.dashboardOrder = opts.dashboardOrder or {"All TODO Items"}
    common.config.dashboard = opts.dashboard or {
        ["All TODO Items"] = {
            {
                type={"TODO"}, --TODO, INFO etc. Gets the items that matches one of the given types. Ignore if its empty
                tags={}, --A list of tags to filter. Ignore if its empty. {AND={"tag1", "tag2"}, OR={"tag1", "tag2"}}
                deadline="", --none (no deadline property), today, past, nearFuture, before-yyyy-mm-dd, after-yyyy-mm-dd. Only looks for TODO items.
                scheduled="", --none, today, past, nearFuture, before-yyyy-mm-dd, after-yyyy-mm-dd. Only looks for TODO items. Ignored if empty.
            },
            --{...},
            --...
        },
    }

    common.config.tagColor = opts.tagColor or "blue"
    common.config.titleColor = opts.titleColor or "yellow"

    common.config.todoTypeColor = opts.todoTypeColor or "cyan"
    common.config.habitTypeColor = opts.habitTypeColor or "cyan"
    common.config.infoTypeColor = opts.infoTypeColor or "lightgreen"
    common.config.dueTypeColor = opts.dueTypeColor or "red"
    common.config.doneTypeColor = opts.doneTypeColor or "green"
    common.config.cancelledTypeColor = opts.cancelledTypeColor or "red"

    common.config.completionColor = opts.completionColor or "lightgreen"

    common.config.scheduledTimeColor = opts.scheduledTimeColor or "cyan"
    common.config.deadlineTimeColor = opts.deadlineTimeColor or "red"

    common.config.habitScheduledColor = opts.habitScheduledColor or "yellow"
    common.config.habitDoneColor = opts.habitDoneColor or "green"
    common.config.habitProgressColor = opts.habitProgressColor or "lightgreen"
    common.config.habitPastScheduledColor = opts.habitPastScheduledColor or "darkyellow"
    common.config.habitFreeTimeColor = opts.habitFreeTimeColor or "blue"
    common.config.habitNotDoneColor = opts.habitNotDoneColor or "red"
    common.config.habitDeadlineColor = opts.habitDeadlineColor or "gray"

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
            vim.opt.foldmethod="marker"
            vim.opt.foldmarker = common.config.foldmarker

            require("md-agenda.insertDate")
            require("md-agenda.checkTask")
            require("md-agenda.agendaView")
            require("md-agenda.habitView")
            require("md-agenda.agendaDashboard")
            require("md-agenda.searchItem")

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

            --Highlight syntax in the buffer
            vim.cmd("highlight todoType guifg="..common.config.todoTypeColor.." ctermfg="..common.config.todoTypeColor)
            --vim.api.nvim_set_hl(5, "todoType", { fg = common.config.todoTypeColor, ctermfg=common.config.todoTypeColor })
            vim.cmd("call matchadd('todoType', 'TODO')")

            vim.cmd("highlight habitType guifg="..common.config.habitTypeColor.." ctermfg="..common.config.habitTypeColor)
            vim.cmd("call matchadd('habitType','HABIT')")

            vim.cmd("highlight dueType guifg="..common.config.dueTypeColor.." ctermfg="..common.config.dueTypeColor)
            vim.cmd("call matchadd('dueType','DUE')")

            vim.cmd("highlight doneType guifg="..common.config.doneTypeColor.." ctermfg="..common.config.doneTypeColor)
            vim.cmd("call matchadd('doneType','DONE')")

            vim.cmd("highlight infoType guifg="..common.config.infoTypeColor.." ctermfg="..common.config.infoTypeColor)
            vim.cmd("call matchadd('infoType','INFO')")

            vim.cmd("highlight cancelledTask guifg="..common.config.cancelledTypeColor.." ctermfg="..common.config.cancelledTypeColor)
            vim.cmd("call matchadd('cancelledTask','CANCELLED')")

            vim.cmd("highlight tag guifg="..common.config.tagColor.." ctermfg="..common.config.tagColor)
            vim.cmd("call matchadd('tag','\\#[a-zA-Z0-9]\\+')")
            vim.cmd("call matchadd('tag',':[a-zA-Z0-9:]\\+:')")

            for customType, itsColor in pairs(common.config.customTodoTypes) do
                vim.cmd("highlight "..customType.." guifg="..itsColor.." ctermfg="..itsColor)
                vim.cmd("call matchadd('"..customType.."', '"..customType.."')")
            end
        end,
    })

end

return M
