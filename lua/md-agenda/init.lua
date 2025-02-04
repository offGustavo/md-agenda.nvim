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
