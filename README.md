# md-agenda.nvim
![GitHub stars](https://img.shields.io/github/stars/zenarvus/md-agenda.nvim?style=flat-square)
![Forks](https://img.shields.io/github/forks/zenarvus/md-agenda.nvim?style=flat-square)
![Issues](https://img.shields.io/github/issues/zenarvus/md-agenda.nvim?style=flat-square)
![License](https://img.shields.io/badge/license-GPL%20v3-blue.svg?style=flat-square)

A Markdown time and task management plugin for NeoVim, inspired by org-agenda.

## Installation/Configuration
### Requirements
- [ripgrep](https://github.com/BurntSushi/ripgrep)

### Using lazy.nvim
```lua
{"zenarvus/md-agenda.nvim",
    config = function ()
        require("md-agenda").setup({
            --- REQUIRED ---
            agendaFiles = {
                "~/notes/agenda.md", "~/notes/habits.md", --Single Files
                "~/notes/agendafiles/", --Folders
            }

            --- OPTIONAL ---
            -- Number of days to display on one agenda view page. Default: 10
            agendaViewPageItems=10
            -- Number of days before the deadline to show a reminder for the task in the agenda view. Default: 30
            remindDeadlineInDays=30
            -- Number of days before the scheduled time to show a reminder for the task in the agenda view. Default: 10
            remindScheduledInDays=10
            
            -- Number of past days to show in the habit view. Default: 24
            habitViewPastItems=24
            -- Number of future days to show in the habit view. Default: 3
            habitViewFutureItems=3
 
            -- For folding logbook entries. Default: {{{,}}}
            foldmarker="{{{,}}}"

            -- Custom types that you can use instead of TODO. Default: {}
            customTodoTypes={SOMEDAY="#ffffff"} -- A map of item type and its color

            -- Customize agenda dashboard view
            dashboardOrder = {"All TODO Items"} -- Order of the dashboard page. Place group names defined in the "dashboard" configuration.
            dashboard = {
                -- Be aware that the map is an array of maps.
                ["All TODO Items"] = {
                    {
                        -- Item types, e.g., {"TODO", "INFO"}. Gets the items that match one of the given types. Ignored if empty.
                        type={"TODO"},

                        -- List of tags to filter. Use AND/OR conditions, e.g., {AND = {"tag1", "tag2"}, OR = {"tag1", "tag2"}}. Ignored if empty.
                        tags={},

                        -- Both, deadline and scheduled filters can take the same parameters.
                        -- "none", "today", "past", "nearFuture", "before-yyyy-mm-dd", "after-yyyy-mm-dd".
                        -- Ignored if empty.
                        deadline="",
                        scheduled="",
                    },
                    --{...}, Additional filter maps can be added in the same group.
                },
                --["Other Group"] = {{...}, ...}
            }

            -- Optional: Change agenda colors.
            tagColor = "blue"
            titleColor = "yellow"

            todoTypeColor = "cyan"
            habitTypeColor = "cyan"
            infoTypeColor = "lightgreen"
            dueTypeColor = "red"
            doneTypeColor = "green"
            cancelledTypeColor = "red"

            completionColor = "lightgreen"
            scheduledTimeColor = "cyan"
            deadlineTimeColor = "red"

            habitScheduledColor = "yellow"
            habitDoneColor = "green"
            habitProgressColor = "lightgreen"
            habitPastScheduledColor = "darkyellow"
            habitFreeTimeColor = "blue"
            habitNotDoneColor = "red"
            habitDeadlineColor = "gray"
        })

        -- Optional: Set keymaps for commands
        vim.keymap.set('n', '<A-t>', ":CheckTask<CR>")
        vim.keymap.set('n', '<A-c>', ":CancelTask<CR>")

        vim.keymap.set('n', '<A-h>', ":HabitView<CR>")
        vim.keymap.set('n', '<A-o>', ":AgendaDashboard<CR>")
        vim.keymap.set('n', '<A-a>', ":AgendaView<CR>")

        vim.keymap.set('n', '<A-s>', ":TaskScheduled<CR>")
        vim.keymap.set('n', '<A-d>', ":TaskDeadline<CR>")

        -- Optional: Create a custom agenda view command to only show the tasks with specific tags
        vim.api.nvim_create_user_command("WorkAgenda", function()
            vim.cmd("AgendaViewWTF work companyA") -- Run the agenda view with tag filters
        end, {})
    end
},
```

## Roadmap
- Use a custom function for folding instead of markers. (Help needed, low priority)
- Update the parent task's progress indicator and type when a subtask is done. (Medium priority)
***

## Agenda Item Structure
**By default, this plugin only considers markdown headers starting with these strings as agenda items:**

| Type | Description |
| - | - |
| **TODO** | Regular tasks. |
| **HABIT** | Habit tracking. Only shown in the habit view. Must contain a repeating scheduled property. |
| **INFO** | Important events for viewing in the agenda view. |
| **DONE** | When a task is completed on time, its type changes to DONE. |
| **DUE** | When a task is completed after the deadline, its type changes to DUE. |
| **CANCELLED** | When a TODO task is cancelled, its type changes to CANCELLED. |

> [!TIP]
> You can also use custom item types instead of **TODO**,
> with the **customTodoTypes** configuration.

**Here are some example agenda items to understand their structure better:**
```md
# TODO: Learn to tie your shoes #tag

# TODO: Mid-term exams :university:tag2:
- Deadline: `2025-02-15 00:00`
- Scheduled: `2025-02-06 00:00`

# DONE: Refresh the fridge
- Completion: `2025-02-01 00:13`

# HABIT: Read a book (17/30)
- Last Repeat: `2025-01-30 16:58`
- Scheduled: `2025-01-31 00:00 .+1d`
<details logbook><!--{{{-->

- DONE: `2025-01-30 16:58` `(36/30)`
- DONE: `2025-01-29 14:28` `(32/30)`
- DONE: `2025-01-28 13:42` `(30/30)`
- DONE: `2025-01-27 17:53` `(30/30)`
- PROGRESS: `2025-01-24 13:27` `(28/30)`
- PROGRESS: `2025-01-23 12:54` `(23/30)`
<!--}}}--></details>

# INFO: International Workers' Day #event
- Scheduled: `2025-05-01 00:00 +1y`
```

### Repeating Tasks
To make an item repeat, add the **repeat indicator** at the end of the **Deadline** or **Scheduled** property.

> [!WARNING] 
> **You cannot add the repeat indicator to both properties in the same task.**

| Repeat Indicator Type | Example |
| :-: | - |
| **"+"** | Shifts the date, e.g., one month ( +1m ) after the scheduled time or deadline. **It can still be in the past and overdue even after checking the task.** |
| **"++"** | Shifts the date by at least one week ( ++1w ) from the scheduled time or deadline, **but also by as many days as it takes to get the same weekday in the future.** |
| **".+"** | Shifts the date to, for example, one month ( .+1m ) **after today**. |

| Repeat Indicator Interval | Description |
| :-: | - |
| **"d"** | n days after. |
| **"w"** | n weeks after, same weekday. |
| **"m"** | n months after, same day of the month. |
| **"y"** | n years after, same month and day of the month. |
| **"x"** | Looks for the occurrence number of the weekday from the start in the month. **Example:** Second Monday in January. Then gets the same date n occurrences after. |
| **"z"** | Looks for the occurrence number of the weekday from the end of the month. **Example:** Last Friday in May. Then gets the same date n occurrences after. |

Still not satisfied? You can also run Lua scripts inside task properties by placing the script's absolute path inside `$()`

**Here is an example:**
```md
<!--test.lua returns a date string in the format used by this plugin.-->
## TODO: Test Task
- Scheduled: `$(/path/to/lua/script/test.lua)`
```

### **Progress Indicator (x/y)**
A progress indicator is split into two parts: the progress **(x)** and the goal **(y)**.
- **In repeating tasks**, upon task completion, the progress is directly saved to the logbook, and the progress in the item is reset.

## Checking/Cancelling a Task
| Command | Description |
| - | - |
| `:CheckTask` | Check the item by placing the cursor on it. |
| `:CancelTask` | If it is a **TODO** or **HABIT**, change the item type to **CANCELLED**. |

> [!TIP]
> You can also check the tasks from the view buffers

> [!WARNING]
> **Items cannot be checked when:**
> 1. The task is malformed.
> 2. The time in the **Scheduled** property has not arrived yet.
> 3. The item type is not **TODO** or **HABIT**.
> 4. The repeating task has a **progress indicator** with a **zero** progress.

**If the agenda item has a repeat indicator**;
- The completed/cancelled task is directly saved to the logbook without changing the task type.
- If the current scheduled time exceeds the given deadline, the task is marked as due.
- If the next scheduled time will exceed the deadline, the task is marked as done.

## Plugin Buffers
> [!TIP]
> To close a buffer, you can use the Escape key.

### Agenda View
| Command | Description |
| - | - |
| `:AgendaView` | Open the agenda view. |
| `:AgendaViewWTF tag1 tag2` | Open the agenda view and only show items containing the specified tags. You can also place item types (e.g., TODO) in the arguments instead of tags. |

> [!TIP]
> To switch between the agenda view pages,
> use the left and right arrow keys.

| Condition | Description |
| - | - |
| No **Scheduled** nor **Deadline** | Not shown in the agenda view. |
| **Scheduled** exists, but not **Deadline** | Shown on the scheduled day. If today is in the past but close to the scheduled time, or if the scheduled time has already passed, it will be shown today. |
| **Deadline** exists, but not **Scheduled** | Shown on the deadline day. A reminder is shown today if the item type is **TODO** and the deadline is close. |
| Both **Scheduled** and **Deadline** exist | Shown on both the scheduled and deadline days. Also shown today if the current date is between them, and the item type is **TODO**. |
| Has a **Repeat Indicator** | Shown on future planned dates until the deadline. |
| **Completion** exists | Shown on the completion day. |
| Has **Logbook** items | Shown on repeat dates. |

To show **reminders about special days** like "April Fools' Day," you can add the [ready-made files](https://github.com/zenarvus/md-agenda.nvim/tree/main/specialDays) to your agendaFiles configuration, or you can create one yourself.

### Agenda Dashboard
For grouping and displaying agenda items by filters in a one-page buffer. Configuration options for it are in the `## Installation/Configuration` section.

| Command | Description |
| - | - |
| `:AgendaDashboard` | Open the agenda dashboard. |

### Habit View
| Command | Description |
| - | - |
| `:HabitView` | Opens the habit view (a.k.a., consistency graph). Only habit items are shown. |

| Color | Condition|
| - | - |
| **Yellow** | If the task is scheduled at that time, or if the habit is scheduled in the past but has not been done, it will be shown in yellow today. |
| **Dark Yellow** | Past scheduled date. |
| **Blue** | No need to do the task at that time. |
| **Green** | Task is completed on that day. |
| **Light Green** | Progress has been made but the task is not completed. |
| **Red** | Task was due to be done that day but was not. |
| **Gray** | Deadline is on that day. |

### Date Selection
Upon running one of the date selection commands, a date selection buffer will appear. You can navigate back and forth using the left and right arrow keys. To insert the date, press Enter.

| Command | Description |
| - | - |
| `:TaskScheduled` | Insert the **Scheduled** property by placing cursor on the agenda item. |
| `:TaskDeadline` | Insert the **Deadline** property by placing cursor on the agenda item. |
