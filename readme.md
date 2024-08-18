# Dima

Dima is a monthly habit tracking program.

https://github.com/user-attachments/assets/6a58aaf6-4842-4f03-bd5a-e38e15524ab5

# Getting the program

[You can download a prebuilt release from the releases page here](https://github.com/thabetx/dima/releases)

Or you can build it from source
1. Download/Clone the code
2. Download the Odin compiler
3. Add the Odin compiler to the path
4. Run `build.bat`

The program's exe will be generated in the build folder.

# File format (Important)
When you run the program, a new file called something like `2024-08.txt` (Year-Month.txt) will be created besides the exe.

That file contents look like this
```
xxxxxxxxxx.....................;Take a Walk;;;
xxxxxxxxxxx.............-------;Read the book;;;START book.pdf
------xxxxx....................;Write;;;START obsidian.lnk
-------------------------------;;;;
x-x-x-x-x-x-.-.-.-.-.-.-.-.-.-.;Study Math;;;
-x-x-x-x-x-.-.-.-.-.-.-.-.-.-.-;Study Programming;;;
```

Each line represents a habit. The line consists of five semicolon-separated parts
1. The state of days (31 marks): `x` is done, `.` is not done, and `-` is canceled
2. The habit name (Optional)
3. Description of the habit (Optional)
4. Purpose of the habit (Optional)
5. Command to launch when clicking on the habit (Optional)

The program itself doesn't edit the habits except for marking habits as done or not done.

So, to add a new habit or edit a current one, you are expected to edit the file in an external text editor.

> [!Tip]
> Pressing `e` will open a text editor on the habits file.

> [!Tip]
> The program watches the habits file on disk. So any change will appear immediately in the program. No need to restart.

# Contribution
Reporting issues and feature suggestions in the issue tracker is very welcome.

Bug-fix PRs are welcome as well.

I didn't need to add any features to the program for a long time. So, features PRs might not get merged. It's better to discuss them in the issue tracker before taking any action.

You are always free to fork and make your changes.

# Advanced Usage

## Theme Editor
There is a theme editor, that can be opened by pressing `t`. Colors are saved automatically to `colors.hex`.

https://github.com/user-attachments/assets/b94e835e-4321-4239-8d7f-293bf0e6cec3

## Syncing
The program operates on files on disk. You can use any syncing solution on the folder (I use SyncThing).

## Using the dash/skipped days strategically
Something I was  surprised about is the versatility of the `-`. Here are some uses:
- Cancel a habit without worrying about it in following days `xxxxxxxx-----------------`
- Add a new habit without affecting the previous days `--------------xx.........`
- Create a separator line `---------------------------;;;;`
- Schedule habits at certain days e.g. weekends `-----xx-----..-----..`
- Create alternating habits
```
-x-x-x-x-x-x-.-.-.-.-.-
x-x-x-x-x-x-.-.-.-.-.-.
```

## Using Commands
The last element of each habit is a command. When clicking on it it executes that command.
Here are some ideas of how I use it
- `START book.pdf`: Open a book for reading
- `START anki`: Start Anki
- `START c:\dev\dima\readme.md`: Open an editor to update the readme of this project
- `START D:\firefox.lnk https://.......`: Open a website for following something

To make commands shorter, you can create shortcuts or add programs to path.

## The timer
Whenever you select a habit, the timer starts running. And when the habit is done, it resets. You can keep an eye on it for simple time tracking or you can ignore it.

## Faster toggling
You can toggle a habit by pressing right click on its name. This will toggle today's status.

# Design Decisions

## The format is similar to CSV with two differences
- Semicolon separated instead of comma Separated: It's more common for me to use commas in the habit name or description compared to semicolons
- No header row: as it's unnecessary to the file format

## Format as text instead of binary
- Easier editing in a text editor, which in turn simplifies the program
- Diffable in case of conflicts
- Easy for other programs to parse, e.g. the Android client

## Scoping to a single month (opinionated)
- A month is a good unit of habit tracking
- The end of a month is a good point for revisiting all habits
- The text format is simple so you can aggregate data across files if you wish
- The program can be extended to show months consecutively if need be
