IF NOT exist build (mkdir build && echo build dir created)
odin build program -debug -build-mode:dll -out:build/program.dll -vet
REM odin build program -o:aggressive -disable-assert -no-bounds-check

