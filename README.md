# BiN-Script-V3

A small C++20 prototype of a scripting-language compiler front-end. This repository currently contains a single-file prototype (src/main.cpp) with a tokenizer, numeric literal parser, a basic AST and parser, and a minimal CLI that parses a hard-coded sample and prints the AST & parser errors.

## Status

Prototype — single source file, no tests, no docs, no CI. If you want this to be a serious project we should split the code into modules, add unit tests, add a proper build/test workflow (CI), and write documentation.

## Requirements

- CMake 3.20 or newer
- A C++20-capable compiler (g++ 11+, clang 13+, MSVC recent)

## Build

From a fresh clone:

```bash
git clone https://github.com/BiN1606-beep/BiN-Script-V3.git
cd BiN-Script-V3
cmake -S . -B build
cmake --build build --config Release
```

Run the program (Linux/macOS):

```bash
./build/BiN-Script-V3/BiN-Script-V3
```

On Windows the executable will typically be in `build\Release\BiN-Script-V3.exe`.

## What a unit test is (short explanation)

A unit test is a small automated program that checks a single "unit" of code (a function, method, or class) in isolation to ensure it behaves correctly. Unit tests help you catch regressions when you change code, document expected behavior, and make refactoring safer.

Key points:
- Granularity: test one thing at a time (e.g., `tokenizer::parseNum` for several number formats).
- Automation: run tests automatically (locally and in CI) instead of manual checks.
- Fast: unit tests should be quick so you run them often.
- Deterministic: tests should not rely on external state (network, time, environment) without control.

Benefits for this project:
- Ensure tokenizer and parser behavior stays stable as you refactor or add features.
- Let you experiment with parser changes without fear of breaking existing behavior.
- Makes it easier for others to contribute because they can verify their changes quickly.

## How we could add unit tests (suggested approach)

I recommend using a single-header test framework like Catch2 or doctest. They integrate well with CMake and are easy to write and run.

1) Add a test target to `CMakeLists.txt` using CMake's `add_executable` and `enable_testing()`.
2) Bring in Catch2 via CMake's `FetchContent` or as a submodule.
3) Add tests/ directory and write focused tests for tokenizer and parseNum.

Example `CMakeLists.txt` additions (concept snippet):

```cmake
include(FetchContent)
FetchContent_Declare(
  catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  GIT_TAG v3.4.0 # choose a stable tag
)
FetchContent_MakeAvailable(catch2)

add_executable(tests tests/test_main.cpp)
target_link_libraries(tests PRIVATE Catch2::Catch2WithMain)
enable_testing()
add_test(NAME unit_tests COMMAND tests)
```

Example test (tests/test_tokenizer.cpp):

```cpp
#include <catch2/catch_test_macros.hpp>
#include "../src/tokenizer.h" // after splitting files

TEST_CASE("parseNum handles hex fractional", "parseNum") {
    double out;
    bool ok = tokenizer::parseNum("0XF.8", out);
    REQUIRE(ok);
    // 0xF.8 == 15.5 (15 + 8/16)
    REQUIRE(out == Approx(15.5));
}

TEST_CASE("tokenize simple var declaration", "tokenize") {
    auto ts = tokenizer::tokenize("var foo: int = 42");
    // assert tokens in order: keyword(var), identifier(foo), symbol(:), identifier(int), symbol(=), number(42)
    REQUIRE(ts.peek().kind == tokenizer::TokenKind::keyword);
    // further checks ...
}
```

Notes:
- Right now the code is in one file. Before adding tests it's helpful to split the code into headers and sources (for example `src/tokenizer.h/cpp`, `src/ast.h/cpp`, `src/parser.h/cpp`) so tests can `#include` the headers without pulling main.
- Alternatively, tests can include `src/main.cpp` temporarily, but splitting is cleaner.

## Next steps (recommended)

- Add a `.gitignore` that ignores `build/` and other artifacts.
- Split `src/main.cpp` into library files and a small `main.cpp` that uses the library.
- Add a `tests/` directory and the CMake test target using Catch2 or doctest.
- Add GitHub Actions CI to build and run tests on push/PR.

If you want, I can make these changes for you now: create a README (done), add .gitignore, split files, and add a simple Catch2 test + CI. Tell me which steps I should perform next and I'll apply them to the repository.
