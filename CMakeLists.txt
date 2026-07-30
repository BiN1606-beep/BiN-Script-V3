cmake_minimum_required(VERSION 3.16)
project(BiN-Script-V3 LANGUAGES CXX)

option(BS_PHONE_COMPAT "Build for phone/Android IDE (strict C++17 subset)" OFF)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (BS_PHONE_COMPAT)
  add_definitions(-DBS_PHONE_BUILD)
endif()

if(MSVC)
  add_compile_options(/W4 /permissive-)
else()
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Keep existing executable target (non-invasive). Later we will refactor core logic into a library target.
add_executable(BiN-Script-V3
    src/main.cpp
)

enable_testing()
add_subdirectory(tests)
