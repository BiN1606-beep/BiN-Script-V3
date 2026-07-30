include(FetchContent)

FetchContent_Declare(
  catch2
  GIT_REPOSITORY https://github.com/catchorg/Catch2.git
  GIT_TAG v3.4.0
)

FetchContent_MakeAvailable(catch2)

add_executable(unit_tests tests/test_example.cpp)

target_link_libraries(unit_tests PRIVATE Catch2::Catch2WithMain)

add_test(NAME unit_tests COMMAND unit_tests)
