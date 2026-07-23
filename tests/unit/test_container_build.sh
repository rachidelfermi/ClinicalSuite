#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# TEST CONFIGURATION
###############################################################################

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly TEST_DIR
REPOSITORY_ROOT="$(cd -- "$TEST_DIR/../.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly BUILD_SCRIPT="$REPOSITORY_ROOT/containers/build.sh"

###############################################################################
# TEST HELPERS
###############################################################################

assert_status() {
    local expected="$1"
    shift

    local actual

    set +e
    "$@" >/dev/null 2>&1
    actual=$?
    set -e

    [[ "$actual" -eq "$expected" ]] || {
        printf 'FAIL: expected status %s, received %s: %s\n' \
            "$expected" "$actual" "$*" >&2
        return 1
    }
}

###############################################################################
# BUILD INTERFACE TESTS
###############################################################################

main() {
    local image_count

    assert_status 0 "$BUILD_SCRIPT" --help
    assert_status 0 "$BUILD_SCRIPT" --list
    assert_status 1 "$BUILD_SCRIPT" --unknown-option
    assert_status 1 "$BUILD_SCRIPT" unsupported-image
    assert_status 1 "$BUILD_SCRIPT" --validate-only qc

    image_count="$("$BUILD_SCRIPT" --list | wc -l)"
    [[ "$image_count" -eq 7 ]] || {
        printf 'FAIL: expected seven image names, received %s\n' "$image_count" >&2
        return 1
    }

    printf 'PASS: container build interface unit tests\n'
}

main "$@"
