#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# TEST CONFIGURATION
###############################################################################

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly TEST_DIR
REPOSITORY_ROOT="$(cd -- "$TEST_DIR/../.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly RUN_SCRIPT="$REPOSITORY_ROOT/run.sh"

###############################################################################
# TEST HELPERS
###############################################################################

assert_status() {
    local expected_status="$1"
    shift

    local actual_status

    set +e
    "$@" >/dev/null 2>&1
    actual_status=$?
    set -e

    if [[ "$actual_status" -ne "$expected_status" ]]; then
        printf 'FAIL: expected status %s, received %s: %s\n' \
            "$expected_status" "$actual_status" "$*" >&2
        return 1
    fi
}

###############################################################################
# ENTRY-POINT CONTRACT TESTS
###############################################################################

test_help_succeeds() {
    assert_status 0 "$RUN_SCRIPT" --help
}

test_default_invocation_is_non_operational() {
    assert_status 69 "$RUN_SCRIPT"
}

test_unknown_argument_is_rejected() {
    assert_status 64 "$RUN_SCRIPT" --unknown-option
}

test_extra_help_argument_is_rejected() {
    assert_status 64 "$RUN_SCRIPT" --help unexpected
}

###############################################################################
# MAIN
###############################################################################

main() {
    test_help_succeeds
    test_default_invocation_is_non_operational
    test_unknown_argument_is_rejected
    test_extra_help_argument_is_rejected
    printf 'PASS: run.sh interface unit tests\n'
}

main "$@"
