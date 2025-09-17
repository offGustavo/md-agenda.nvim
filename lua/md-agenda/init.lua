local vim = vim

local function setup(opts)
	local config = require("md-agenda.config").initConfig(opts)

	local common = require("md-agenda.common")

	local insertDate = require("md-agenda.insertDate")
	local checkTask = require("md-agenda.checkTask")
	local updateProgress = require("md-agenda.updateProgress")
	local agendaView = require("md-agenda.agendaView")
	local habitView = require("md-agenda.habitView")
	local agendaDashboard = require("md-agenda.agendaDashboard")

	--Date Picker
	vim.api.nvim_create_user_command('TaskScheduled', function()
		local currentBufNum = vim.api.nvim_get_current_buf()
		insertDate.dateSelector(vim.api.nvim_buf_get_name(0),"scheduled",currentBufNum)
	end, {})
	vim.api.nvim_create_user_command('TaskDeadline', function()
		local currentBufNum = vim.api.nvim_get_current_buf()
		insertDate.dateSelector(vim.api.nvim_buf_get_name(0),"deadline",currentBufNum)
	end, {})

	--Agenda View
	vim.api.nvim_create_user_command('AgendaView',agendaView.agendaView, {})
	vim.api.nvim_create_user_command('AgendaViewWTF', function(avOpts)agendaView.agendaViewWTF(avOpts)end, {nargs = '*'})

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

	--- List all habit files
	local HabitFiles = common.listFiles(config.config.habitFiles)

	if #HabitFiles > 0 then
		-- Store the user's current fold settings
		local HabitOldFoldMethod = vim.o.foldmethod
		local HabitOldFoldMarker = vim.o.foldmarker

		vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
			pattern = HabitFiles,
			callback = function()
				-- Apply custom fold settings when entering a habit file
				vim.o.foldmethod = "marker"
				vim.o.foldmarker = config.config.foldmarker
			end,
		})

		vim.api.nvim_create_autocmd("BufLeave", {
			pattern = HabitFiles,
			callback = function()
				-- Restore the user's original fold settings when leaving
				vim.o.foldmethod = HabitOldFoldMethod
				vim.o.foldmarker = HabitOldFoldMarker
			end,
		})
	end

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "markdown",
		callback = function()

			--Check Task -- (Modify the current buffer and the current line in markdown documents. This changes in the view buffers.)
			vim.api.nvim_buf_create_user_command(0, 'CheckTask', function()
				local currentBufNum = vim.api.nvim_get_current_buf()
				checkTask.taskAction(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], "check", currentBufNum)
			end, {})
			vim.api.nvim_buf_create_user_command(0, 'CancelTask', function()
				local currentBufNum = vim.api.nvim_get_current_buf()
				checkTask.taskAction(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], "cancel", currentBufNum)
			end, {})

			--Update Progress--
			vim.api.nvim_buf_create_user_command(0, 'UpdateProgress', function()
				local progressCount = vim.fn.input("New Progress: ")
				if #progressCount == 0 then
					print("No change")
					return
				elseif not tonumber(progressCount) then
					print("Invalid progress count")
					return
				end
				local currentBufNum = vim.api.nvim_get_current_buf()
				updateProgress.updateTaskProgress(vim.api.nvim_buf_get_name(0), vim.api.nvim_win_get_cursor(0)[1], tonumber(progressCount), currentBufNum)
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
