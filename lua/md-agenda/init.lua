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

    --Custom item type support:
    -- {
    -- customTodoTypes={"SIGMA","CHUD"}
    -- customCompletionTypes={"CANCELLED"}
    -- maybe even theirMap{SIGMA="CANCELLED", CHUD="DONE"}
    -- 
    -- } -- I may also need a function to list custom types while checking.

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
        end,
    })

end

return M
