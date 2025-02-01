M = {}

M.setup = function(opts)
    local common = require("md-agenda.common")
    common.config.agendaFiles = opts.agendaFiles or {}
    common.config.agendaViewPageItems = opts.agendaViewPageItems or 10
    common.config.remindDeadlineInDays = opts.remindDeadlineInDays or 30

    common.config.habitViewPastItems = opts.habitViewPastItems or 24
    common.config.habitViewFutureItems = opts.habitViewFutureItems or 3
    common.config.foldmarker = opts.folmarker or "{{{,}}}"

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
            vim.opt.foldmethod="marker"
            vim.opt.foldmarker = common.config.foldmarker

            common.saveRemoteAgendaFiles()

            require("md-agenda.insertDate")
            require("md-agenda.checkTask")
            require("md-agenda.agendaView")
            require("md-agenda.habitView")
        end,
    })

end

return M
