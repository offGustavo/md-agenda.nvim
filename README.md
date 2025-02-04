# md-agenda.nvim
Markdown time and task management plugin for NeoVim, inspired by org-agenda.

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
            showNonTimeawareTasksToday=false --Show agenda items that has no scheduled time nor deadline in today.
            remindDeadlineInDays=30 --In how many days before the deadline, a reminder for the todo task should be shown today? - default: 30
            remindScheduledInDays=10 --In how many days before the scheduled time, a reminder for the todo task should be shown today? - default: 10
            habitViewPastItems=24 --How many past days should be in the habit view? - default: 24
            habitViewFutureItems=3 --How many future days should be in the habit view? -default: 3
            foldmarker="{{{,}}}" --For folding logbook entries -default: {{{,}}}

            --Custom types that you can use instead of TODO - default: {}
            customTodoTypes={SOMEDAY="#ffffff"} --map of item type and it's color

            --optional, customize agenda dashboard view
            dashboardOrder = {"All TODO Items"} --Order of the dashboard page. Place group names defined in dashboard configuration.
            dashboard = {
                ["All TODO Items"] = {
                    {
                        type={"TODO"}, --TODO, INFO etc. Gets the items that matches one of the given types. Ignore if its empty
                        tags={}, --{AND={"tag1", "tag2"}, OR={"tag1", "tag2"}} A list of tags to filter. Ignore if its empty.
                        deadline="", --"none" (no deadline property), "today", "past", "nearFuture", "before-yyyy-mm-dd", "after-yyyy-mm-dd".
                        scheduled="", --"none", "today", "past", "nearFuture", "before-yyyy-mm-dd", "after-yyyy-mm-dd". Ignored if empty.
                    },
                    --{...},
                    --...
                },
                --["Other Group"] = {...}
            }

            --optional, change agenda colors.
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

        --optional: set keymaps for commands
        vim.keymap.set('n', '<A-t>', ":CheckTask<CR>")
        vim.keymap.set('n', '<A-c>', ":CancelTask<CR>")

        vim.keymap.set('n', '<A-h>', ":HabitView<CR>")
        vim.keymap.set('n', '<A-o>', ":AgendaDashboard<CR>")
        vim.keymap.set('n', '<A-a>', ":AgendaView<CR>")
        vim.keymap.set('n', '<A-Left>', ":PrevAgendaPage<CR>")
        vim.keymap.set('n', '<A-Right>', ":NextAgendaPage<CR>")

        vim.keymap.set('n', '<A-s>', ":TaskScheduled<CR>")
        vim.keymap.set('n', '<A-d>', ":TaskDeadline<CR>")

        vim.keymap.set('n', '<A-f>', ":TaskSearch<CR>")

        --optional: create your own agenda view command to show tasks with a specific tag only
        vim.api.nvim_create_user_command("WorkAgenda", function()
            vim.cmd("AgendaViewWTF work companyA") --Run the agenda view with tag filters
        end, {})
    end
},
```

## Roadmap
- Use a custom function for folding instead of markers. (help needed, low priority)
- Highlight syntax if not using TreeSitter. (high priority)
- Update the parent task's progress indicator and type if a sub task is done. (medium priority)
***

## Agenda Item Structure

**By default, this plugin only considers markdown headers starting with these strings as agenda items:**

| Type | Description |
| - | - |
| **TODO** | For regular tasks. |
| **HABIT** | For habit tracking. Only shown in the habit view. It must contain a repeating scheduled property. |
| **INFO** | Just for viewing important events in the agenda view. |
| **DONE** | When a task is completed in time, it's type changes to DONE. |
| **DUE** | When a task is completed after the given deadline, it's type changes to DUE. |
| **CANCELLED** | When a TODO task is cancelled, it's type changes to CANCELLED. |

- You can also use custom item types instead of **TODO** with customTodoTypes configuration.

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

```md
    v--- Task Type          v--- Progress Indicator
## TODO: Task description (2/n) #tag
- Deadline: `2024-03-03 12:32`
- Scheduled: `2024-01-04 14:25 +2d`
  ^--- Task Properties          ^-- Repeat Indicator

<details logbook>

          v--- Repeat Date
  - [x] `2024-02-03 13:24` `(n/n)` <--- Logbook Item
                 Progress ---^ ^--- Goal
</details>
```

### Repeating Tasks
**To make an item repeated**, you should add **the repeat indicator** at the end of the **Deadline** or **Scheduled** property.

<mark>**You cannot add the repeat indicator to both of them at the same task.**</mark>

| Repeat Indicator Type | Description |
| :-: | - |
| **"+"** | Shifts the date to, for example, one month **( +1m )** after the scheduled time or deadline. It can be still in the past and overdue even after checking the task. |
| **"++"** | Shifts the date by, for example, at least one week **( ++1w )** from scheduled time or deadline, but also by as many days as it takes to get the same weekday into the future. |
| **".+"** | Shifts the date to, for example, one month **( .+1m )** after today. |

| Repeat Indicator Interval | Description |
| :-: | - |
| **"d"** | n day after. |
| **"w"** | n week after, same weekday. |
| **"m"** | n month after, same day of the month. |
| **"y"** | n year after, same month and day of the month. |
| **"x"** | Looks for the weekday's occurrence number from the start in the month. **Example:** Second Monday in January. Then gets the same date n occurrence after. |
| **"z"** | Looks for the weekday's occurrence number from the end in the month. **Example:** Last Friday in May. Then gets the same date n occurrence after. |

Still not satisfied? You can also run lua scripts inside task properties by placing the script's absolute path inside `$()`

**Here is an example:**
```md
<!--test.lua returns a date string in the format used by this plugin.-->
## TODO: Test Task
- Scheduled: `$(/path/to/lua/script/test.lua)`
```

### **Progress Indicator; (x/y)**
A Progress indicator is splitted into two parts. The **progress (x)** and the **goal (y)**.

- **In repeating tasks**, upon task checking, the progress is directly saved to the logbook and progress in the item is reseted.

## Checking a Task
| Command | Description |
| - | - |
| `:CheckTask` | Check the item by placing the cursor on it. |
| `:CancelTask` | If its **TODO**, change the item type to **CANCELLED** |

<mark>**Items cannot be checked when:**</mark>
1. The task is malformed.
2. The time in **Scheduled** property did not arrive.
3. The item type is not **TODO** or **HABIT**.
4. Repeating task has a **progress indicator** with a **zero** progress.

**If the agenda item has a repeat indicator**;
- the completed task is directly saved to the logbook without any change on the task type.
- if the current scheduled time exceeds the given deadline, the task is marked as due.
- if the next scheduled time is going to exceed the given deadline, the task is marked as done.

## Agenda View
| Command | Description |
| - | - |
| `:AgendaView` | Open the agenda view. |
| `:AgendaViewWTF tag1 tag2` | Open the agenda view, and only show items which contains given tags. You can also place item types like TODO to the arguments instead of tags.|
| `:PrevAgendaPage` `:NextAgendaPage` | Switch between pages back and forth respectively. (Pages are relative to today.)|

| Condition | Description |
| - | - |
| no **Scheduled** nor **Deadline** | If its **TODO**, its shown today. |
| **Scheduled** exists but not **Deadline** | Its shown in the scheduled day. Also, in today until its finished. |
| **Deadline** exists but not **Scheduled** | Its shown in the deadline day. Also, based on the configuration, a reminder is shown today if the agenda type is **TODO**. |
| Both **Scheduled** and **Deadline** exists | It is shown in both deadline and scheduled days. Also shown in today if the current date is between them and the agenda type is **TODO**. |
| Has **Repeat Indicator** | It is shown in the future planned dates until the deadline. |
| **Completion** exists | It is shown in the completion day. |
| Has **Logbook** items | It is shown in the repeat dates. |

To show **reminders about special days like "April Fools' Day,"** you can add the [ready-made files](https://github.com/zenarvus/md-agenda.nvim/tree/main/specialDays) to your agendaFiles configuration, or you can create one yourself.

## Agenda Dashboard
For grouping and displaying agenda items by filters in one page buffer.

| Command | Description |
| - | - |
| `:AgendaDashboard` | Open the agenda dashboard. |

## Habit View
| Command | Description |
| - | - |
| `:HabitView` | Opens the habit view (aka: consistency graph.) Only habit items are shown in it. |

| Color | Condition|
| - | - |
| <span style="color:yellow">**Yellow**</span> | If the task is scheduled on that time. Also, If the habit is scheduled in the past but has not been made, today is shown in yellow. |
| <span style="color:#DEC20B">**Dark Yellow**</span> | The passed scheduled date. |
| <span style="color:blue">**Blue**</span> | If you do not have to do the task on that time. |
| <span style="color:green">**Green**</span> | If the task is done on that day. |
| <span style="color:lightgreen">**Light Green**</span> | If progress had been made but the task was not done. |
| <span style="color:red">**Red**</span> | If the task had to be done that day but it was not. |
| <span style="color:gray">**Gray**</span> | If the deadline is on that time. |

## Date Selection
Upon running one of the date selection commands, telescope will list date items starting from today to next 365 days.

| Command | Description |
| - | - |
| `:TaskScheduled` | Insert **Scheduled** property by placing cursor on the agenda item. |
| `:TaskDeadline` | Insert **Deadline** property by placing cursor on the agenda item. |


## Agenda Item Search
| Command | Description |
| - | - |
| `:TaskSearch` | Lists all agenda items with telescope and navigates to the selected item's location. |
