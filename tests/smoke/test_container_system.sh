#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# TEST CONFIGURATION
###############################################################################

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly TEST_DIR
REPOSITORY_ROOT="$(cd -- "$TEST_DIR/../.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly CONTAINER_DIR="$REPOSITORY_ROOT/containers"
readonly -a IMAGE_NAMES=(
    qc alignment gatk octopus deepvariant annotation report
)

###############################################################################
# TEST HELPERS
###############################################################################

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    return 1
}

###############################################################################
# STRUCTURAL TESTS
###############################################################################

test_required_files() {
    local image_name

    [[ -x "$CONTAINER_DIR/build.sh" ]] || fail 'build.sh is not executable'
    [[ -x "$CONTAINER_DIR/validate.sh" ]] || fail 'validate.sh is not executable'
    [[ -f "$CONTAINER_DIR/versions.lock" ]] || fail 'versions.lock is missing'
    [[ -f "$CONTAINER_DIR/requirements/report.txt" ]] || \
        fail 'report requirements lock is missing'

    for image_name in "${IMAGE_NAMES[@]}"; do
        [[ -f "$CONTAINER_DIR/definitions/$image_name.def" ]] || \
            fail "missing definition: $image_name.def"
    done
}

test_pinning_and_data_boundary() {
    local -a definitions=()

    mapfile -t definitions < <(
        find "$CONTAINER_DIR/definitions" -name '*.def' -type f -print
    )
    [[ ${#definitions[@]} -gt 0 ]] || fail 'no definition files found'

    if grep -Eni '(^|[/:])latest([[:space:]@]|$)' "${definitions[@]}"; then
        fail 'floating latest reference found in a definition'
    fi

    if grep -Eni 'GRCh38|ClinVar|dbSNP|gnomAD|VEP.cache|CADD|REVEL|SpliceAI|dbNSFP' \
        "${definitions[@]}"; then
        fail 'forbidden reference or database acquisition found in a definition'
    fi

    grep -Eq 'sha256:[0-9a-f]{64}' "${definitions[@]}" || \
        fail 'definitions do not contain immutable OCI digests'
}

test_built_images() {
    local image_name

    [[ "${1:-}" == '--require-images' ]] || return 0

    for image_name in "${IMAGE_NAMES[@]}"; do
        [[ -s "$CONTAINER_DIR/$image_name.sif" ]] || \
            fail "missing built image: $image_name.sif"
    done
}

test_locked_definition_checksums() {
    local kind
    local name
    local version
    local source
    local expected_sha256
    local license
    local actual_sha256

    while IFS=$'\t' read -r \
        kind name version source expected_sha256 license; do
        [[ "$kind" == definition ]] || continue

        actual_sha256="$(sha256sum "$CONTAINER_DIR/$source" | awk '{print $1}')"
        [[ "$actual_sha256" == "$expected_sha256" ]] || \
            fail "lock checksum mismatch: $source"
    done <"$CONTAINER_DIR/versions.lock"
}

###############################################################################
# MAIN
###############################################################################

main() {
    test_required_files
    test_pinning_and_data_boundary
    test_locked_definition_checksums
    test_built_images "${1:-}"
    printf 'PASS: container system smoke test\n'
}

main "$@"
