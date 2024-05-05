IF NOT exist build (mkdir build && echo build dir created)
odin build main -debug -out:build/dima-deb.exe && pushd build && dima-deb.exe && popd
REM odin build main -o:aggressive -out:build/dima.exe -subsystem:windows -disable-assert -no-bounds-check && pushd build && dima.exe && popd
