# Dima

Dima is a monthly habit tracking program.

![2024-08-12-00_33_42](https://github.com/user-attachments/assets/37dae771-f83f-4cfd-bfdb-9053b0f1aa28)



# Getting the program

[You can download a prebuilt release from the releases page](https://github.com/thabetx/dima/releases)

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
