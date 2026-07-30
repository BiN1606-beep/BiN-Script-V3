# BiN-Script-V3

BiN-Script-V3 is an experimental compiler/language project by BiN. This branch adds a minimal CMake test skeleton and CI to ensure the repository builds on common platforms.

Building (MinGW-w64)

From a MinGW shell (MSYS2/MINGW64):

```sh
mkdir build
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release ..
cmake --build . -- -j
```

Building (generic CMake)

```sh
mkdir build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -- -j
```

Phone compatibility

To build with the phone-compatible flags (limited C++17 subset):

```sh
cmake -S . -B build -DBS_PHONE_COMPAT=ON -G "MinGW Makefiles"
cmake --build build
```

Running tests

```sh
ctest --test-dir build --output-on-failure
```
