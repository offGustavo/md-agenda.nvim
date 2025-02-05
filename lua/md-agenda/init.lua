local function setup(opts)
    local config = require("md-agenda.config").initConfig(opts)

    local common = require("md-agenda.common")

    vim.api.nvim_create_autocmd("FileType", {
        pattern = "markdown",
        callback = function()
            vim.opt.foldmethod="marker"
            vim.opt.foldmarker = config.config.foldmarker

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
            vim.cmd("highlight todoType guifg="..config.config.todoTypeColor.." ctermfg="..config.config.todoTypeColor)
            --vim.api.nvim_set_hl(5, "todoType", { fg = config.config.todoTypeColor, ctermfg=config.config.todoTypeColor })
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
