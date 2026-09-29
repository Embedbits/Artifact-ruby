set(RUBY_CURRENT_LIST_DIR ${CMAKE_CURRENT_LIST_DIR})
#------------------------------------------------------------------------------#
# Returns artifact version.
#
# The name of function must consist of folder name (ruby) and postfix
# (_GetArtifactVersion). Otherwise the buildprocess will fail.
#
# Queries the interpreter resolved by ruby_ArtifactInit() (RUBY_EXECUTABLE),
# falls back to "ruby" from PATH if the artifact was not initialized.
#
# RET_VERSION [out]: Version of artifact in format X.Y.Z
#------------------------------------------------------------------------------#
function(ruby_GetArtifactVersion RET_VERSION)

    if(RUBY_EXECUTABLE)
        set(RUBY_COMMAND "${RUBY_EXECUTABLE}")
    else()
        set(RUBY_COMMAND ruby)
    endif()

    execute_process(COMMAND "${RUBY_COMMAND}" --version
                    OUTPUT_VARIABLE ARTIFACT_VERSION
                    OUTPUT_STRIP_TRAILING_WHITESPACE)

    string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" VERSION "${ARTIFACT_VERSION}")

    set(${RET_VERSION} "${VERSION}" PARENT_SCOPE)

endfunction()


#------------------------------------------------------------------------------#
# Initialize artifact for build.
#
# The name of function must consist of folder name (ruby) and postfix
# (_ArtifactInit). Otherwise the buildprocess will fail.
#
# Binary part is a portable Ruby installation repacked by Ruby_Importer.sh
# with the installation root (bin/, lib/, ...) at the top of the archive:
#   Win       - RubyInstaller2 portable build (without MSYS2 DevKit)
#   Unix      - Homebrew portable-ruby (x86_64_linux)
#   DarwinARM - Homebrew portable-ruby (arm64_big_sur)
#
# Ruby is an interpreter, not a toolchain - this only puts the resolved bin/
# directory on PATH (exposing ruby, gem, bundle, ...). No CMAKE_TOOLCHAIN_FILE
# is set.
#
# NOTE: set(ENV{PATH} ...) below only affects the running CMake configure
# process. It does NOT reach commands added via add_custom_target/
# add_custom_command, since those run later as a separate build-tool
# process (ninja/make) that does not inherit configure-time ENV changes.
# For that reason this function also exports the resolved absolute
# interpreter path as the CACHE variable RUBY_EXECUTABLE - use that (not a
# bare "ruby") inside any COMMAND that runs at build time, e.g.:
#
#   add_custom_command(OUTPUT ${RUNNER_FILE}
#       COMMAND ${RUBY_EXECUTABLE} ${UNITY_ROOT}/auto/generate_test_runner.rb
#               ${TEST_SOURCE} ${RUNNER_FILE}
#       DEPENDS ${TEST_SOURCE})
#
# ARTIFACT_BIN_PATH_ARG [in]: Path to the binary part of artifact
#------------------------------------------------------------------------------#
function(ruby_ArtifactInit ARTIFACT_BIN_PATH_ARG)

    if(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Windows")
        set(RUBY_FILE_NAME "ruby.exe")
        set(PATH_SEPARATOR ";")
    else()
        set(RUBY_FILE_NAME "ruby")
        set(PATH_SEPARATOR ":")
    endif()

    file(GLOB_RECURSE RUBY_FILES "${ARTIFACT_BIN_PATH_ARG}/*/${RUBY_FILE_NAME}")

    # Only the interpreter in bin/ - skips rubyw.exe and any "ruby" named
    # files/directories inside lib/.
    list(FILTER RUBY_FILES INCLUDE REGEX "/bin/${RUBY_FILE_NAME}$")

    if(RUBY_FILES)

        list(GET RUBY_FILES 0 RUBY_FILE)

        get_filename_component(RUBY_BIN_DIR "${RUBY_FILE}" DIRECTORY)

        message(STATUS "File ${RUBY_FILE_NAME} found in: ${RUBY_BIN_DIR}")

        set(ENV{PATH} "${RUBY_BIN_DIR}${PATH_SEPARATOR}$ENV{PATH}")

    else()

        message(FATAL_ERROR "File ${RUBY_FILE_NAME} not found in: ${ARTIFACT_BIN_PATH_ARG}")

    endif()

    set(RUBY_EXECUTABLE "${RUBY_FILE}" CACHE FILEPATH "Absolute path to the resolved Ruby interpreter" FORCE)

    message(DEBUG "Ruby bin directory added to PATH: ${RUBY_BIN_DIR}")
    message(DEBUG "RUBY_EXECUTABLE set to: ${RUBY_EXECUTABLE}")

endfunction()
