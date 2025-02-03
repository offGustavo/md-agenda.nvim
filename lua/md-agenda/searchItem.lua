--For :TaskSearch command. List all tasks in the telescope.

local common = require("md-agenda.common")

local function itemSearch()
    local agendaItems = {}

    for _,agendaFilePath in ipairs(common.listAgendaFiles()) do
        local file_content = vim.fn.readfile(agendaFilePath)
        if file_content then
            local lineNumber = 0
            for _,line in ipairs(file_content) do
                lineNumber = lineNumber+1

                local taskType,title = line:match("^#+ (.+): (.*)")
                if (taskType=="TODO" or taskType=="DONE" or taskType=="DUE" or taskType=="INFO") and title then
                    table.insert(agendaItems, {agendaFilePath, lineNumber, line})

                end
            end
        end
    end

    local telescopePickers = require('telescope.pickers')
    local telescopeFinders = require('telescope.finders')
    local telescopeActions = require('telescope.actions')
    local telescopeState = require('telescope.actions.state')
    local telescopeConf = require("telescope.config").values

    -- Use Telescope to select a suggestion
    telescopePickers.new({}, {
        prompt_title = "Select A Date",
        finder = telescopeFinders.new_table {
            results = agendaItems,
            entry_maker = function(entry)
                return {
                    value = entry[1],
                    lnum = entry[2],
                    display = entry[3],
                    ordinal = entry[3]
                }
            end,
        },
        sorter = telescopeConf.file_sorter(),
        attach_mappings = function(prompt_bufnr, map)
            telescopeActions.select_default:replace(function()
                telescopeActions.close(prompt_bufnr)
                local selection = telescopeState.get_selected_entry()

                if selection then
                    -- Open the file
                    vim.cmd('edit ' .. selection.value)
                    -- Move to the specified line
                    vim.cmd('normal! ' .. selection.lnum .. 'G')
                end
            end)
            return true
        end,
    }):find()

end

vim.api.nvim_create_user_command('TaskSearch', itemSearch, {})
