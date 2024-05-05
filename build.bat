IF NOT exist build (mkdir build && echo build dir created)
odin build main -o:aggressive -out:build/dima.exe -subsystem:windows -disable-assert -no-bounds-check && echo "dima.exe built in the build folder"
pause
