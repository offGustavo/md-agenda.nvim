# md-agenda.nvim
Org-Agenda like, Markdown time and task management plugin for NeoVim.

If you had found a bug or you have a good idea, please open an issue.

## Installation
### Requirements
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [ripgrep](https://github.com/BurntSushi/ripgrep)

### Using lazy.nvim
```lua
{"zenarvus/md-agenda.nvim",
    config = function ()
        require("md-agenda").setup({
            --required
            agendaFiles = {
                "~/notes/agenda.md", "~/notes/habits.md", --singular files
                "~/notes/agendafiles/", --folders
            }

            --optional
            agendaViewPageItems=10 --How many days should be in one agenda view page? - default: 10
            remindDeadlineInDays=30 --In how many days before the deadline, a reminder for the task should be shown today - default: 30
            habitViewPastItems=24 --How many past days should be in the habit view? - default: 24
            habitViewFutureItems=3 --How many future days should be in the habit view? -default: 3
            foldmarker="{{{,}}}" --For folding logbook entries -default: {{{,}}}
        })

        --optional: set keymaps for commands
        vim.keymap.set('n', '<A-t>', ":CheckTask<CR>")

        vim.keymap.set('n', '<A-h>', ":HabitView<CR>")
        vim.keymap.set('n', '<A-a>', ":AgendaView<CR>")
        vim.keymap.set('n', '<A-Left>', ":PrevAgendaPage<CR>")
        vim.keymap.set('n', '<A-Right>', ":NextAgendaPage<CR>")

        vim.keymap.set('n', '<A-s>', ":TaskScheduled<CR>")
        vim.keymap.set('n', '<A-d>', ":TaskDeadline<CR>")

        --optional: create your own agenda view command to show tasks with a specific tag only
        vim.api.nvim_create_user_command("WorkAgenda", function()
            vim.cmd("AgendaViewWTF work companyA") --Run the agenda view with tag filters
        end, {})
    end
},
```

## Roadmap
- Using a custom function for folding instead of markers. (medium priority)

---

## Agenda Item Structure
Here are some example tasks:
```md
# TODO: Learn to tie your shoes #tag

# TODO: Mid-term exams :university:vimwikiTag:
- Deadline: `2025-02-15 00:00`
- Scheduled: `2025-02-06 00:00`

# DONE: Refresh the fridge
- Completion: `2025-02-01 00:13`

# HABIT: Read a book (17/30)
- Last Completion: `2025-01-30 16:58`
- Scheduled: `2025-01-31 00:00 .+1d`
<details logbook><!--{{{-->

 - [x] `2025-01-30 16:58` `(36/30)`
 - [x] `2025-01-29 14:28` `(32/30)`
 - [x] `2025-01-28 13:42` `(30/30)`
 - [x] `2025-01-27 17:53` `(30/30)`
 - [ ] `2025-01-24 13:27` `(28/30)`
 - [ ] `2025-01-23 12:54` `(23/30)`
<!--}}}--></details>

# INFO: International Workers' Day #event
- Scheduled: `2025-05-01 00:00 +1y`
```
### Agenda Item Types
This plugin considers markdown headers that starts with these strings as agenda items:

**TODO:**\
Regular agenda item that should be done.
- Can hold "Deadline" and "Scheduled" properties.
- Can be a repeating task.

**HABIT:**\
An agenda item for habit tracking.
- Only shown in the habit view.
- It must contain a repeating "Scheduled" property.

**INFO:**\
Only for viewing in the agenda view. Useful for holidays, anniversaries etc.
- It must contain a repeating "Scheduled" property.

**DONE:**\
If a task item is completed before the deadline, it is marked as done.
- For repeating tasks, if the next scheduled time is going to exceed the given deadline, the task is marked as done.

**DUE:**\
If a task item is completed after the deadline, it is marked as due.
- For repeating tasks, if the current scheduled time exceeds the given deadline, the task is marked as due.

### Repeating Tasks
To make a task repeating, you should add the repeat indicator at the end of the "Deadline" or "Scheduled" property.
- You cannot add the repeat indicator to both of them at the same task.

**Repeat Indicator Types**:
- **"+"**: Shifts the date to, for example, one month (+1m) after the scheduled time or deadline. It can be still in the past and overdue even after marking it.
- **"++"**: Shifts the date by, for example, at least one week (++1w) from scheduled time or deadline, but also by as many days as it takes to get the same weekday into the future.
- **".+"**: Shifts the date to, for example, one month (.+1m) after today.

**Repeat Indicator Intervals**:
- **"d"**: n day after.
- **"w"**: n week after, same weekday.
- **"m"**: n month after, same day of the month.
- **"y"**: n year after, same month and day of the month.

+ **"x"**: Looks for the weekday's occurrence number from the start in the month. Example: Second Monday in January. Then gets the same date n occurrence after.
+ **"z"**: Looks for the weekday's occurrence number from the end in the month. Example: Last Friday in May. Then gets the same date n occurrence after.

Still not satisfied? You can also run lua scripts inside task properties by placing the script's absolute path inside $(). Here is an example:
```md
<!--test.lua returns a date string in the format used by this plugin.-->
<!--By doing this, you can show this task in the graph view, in the returned date.-->
## TODO: Test Task
- Scheduled: `$(/path/to/lua/script/test.lua)`
```

**Progress Indicator**:\
If you want to save the progress to the logbook, place progress indicator to the task.

Progress indicator looks like this: (x/y). y is the goal and x is the current progress.

## Checking a Task
To check a task, place cursor to it and use `:CheckTask` command.

Tasks cannot be checked when:
- The task is malformed
- Scheduled time did not arrive
- The task is DONE, DUE or INFO
- Repeating task has a progress indicator with a zero progress

If the task is a repeating task, the completed task is directly saved to the logbook without any change in the task type.

## Agenda View
Use `:AgendaView` command to open agenda view. To switch between pages, use `:PrevAgendaPage` and `:NextAgendaPage`. (Pages are relative to today)

Or if you want to show tasks with specific tags only, use `:AgendaViewWTF tag1 tag2`

**Behavior**:
+ If the task has a scheduled time but no deadline time, it is shown on the scheduled day. Also, it is shown today until finished.
+ If the task has a deadline time but no scheduled time, it is shown on the deadline day. Also, based on the configuration, if today is close to the deadline, it's shown today.
+ If the task has both a deadline and scheduled time, it is shown in both the deadline and scheduled time. Also, if today is between these times, it is shown today.
+ If the task is a repeating task, it is shown in the scheduled time and the next days based on the repeat indicator until the deadline.
+ If the task has no deadline nor scheduled time, it is shown today.

## Habit View
To open the habit view, use `:HabitView` command. Only habit tasks shown in the habit view.

**Colors**
- **Yellow**: If the task is scheduled on that time.
- **Blue**: If you do not have to do the task on that time.
- **Green**: If the task is done on that day.
- **Light Green**: If progress had been made but the task was not done.
- If the habit is scheduled in the past but has not been made
  + Today is shown in **yellow**
  + That past scheduled day is shown in **dark yellow**.
- **Red**: If task had to be done that day but it was not.
- **Gray**: If the deadline on that time.

### Special Days and Holidays
To show special days like april fools' day in the graph view, download the files you want in [specialDays](https://github.com/zenarvus/md-agenda.nvim/tree/main/specialDays) folder and add them to the agendaFiles configuration. They only contain events in fixed, non changing dates in Gregorian calendar.

You may consider creating your own and, if it contains non-fixed dates, updating with a script.

## Date Selection
To insert a deadline or scheduled time, place cursor to the task and use one of the `:TaskDeadline` or `:TaskScheduled` commands.\
Telescope will list date items starting from today to next 364 days.
