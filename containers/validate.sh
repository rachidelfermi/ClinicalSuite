#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=containers/lib.sh
source "$SCRIPT_DIR/lib.sh"
readonly REPORT_FILE="$SCRIPT_DIR/container_validation_report.txt"
readonly CHECKSUM_FILE="$SCRIPT_DIR/checksums.sha256"
readonly -a IMAGE_NAMES=(
    "${CLINICAL_CONTAINER_IMAGES[@]}"
)

PASS_COUNT=0
FAIL_COUNT=0
REPORT_TEMPORARY=''

###############################################################################
# CLEANUP AND REPORTING
###############################################################################

cleanup() {
    if [[ -n "$REPORT_TEMPORARY" && -f "$REPORT_TEMPORARY" ]]; then
        rm -f -- "$REPORT_TEMPORARY"
    fi
}

trap cleanup EXIT

write_header() {
    {
        printf 'ClinicalSuite V2 container validation report\n'
        printf 'Generated (UTC): %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf 'Host Apptainer: %s\n' "$(apptainer --version)"
        printf 'Validation mode: executable/version and external-resource boundary checks\n'
        printf '\n'
    } >"$REPORT_TEMPORARY"
}

record_check() {
    local image_name="$1"
    local check_name="$2"
    local expected_pattern="$3"
    shift 3

    record_check_status "$image_name" "$check_name" "$expected_pattern" 0 "$@"
}

record_check_status() {
    local image_name="$1"
    local check_name="$2"
    local expected_pattern="$3"
    local expected_status="$4"
    shift 4

    local image_path="$SCRIPT_DIR/$image_name.sif"
    local output
    local status
    local result=PASS
    local quoted_command

    printf -v quoted_command '%q ' "$@"

    set +e
    output="$(apptainer exec --cleanenv --containall "$image_path" "$@" 2>&1)"
    status=$?
    set -e

    if [[ $status -ne $expected_status ]] || \
        ! grep -Eq -- "$expected_pattern" <<<"$output"; then
        result=FAIL
        ((FAIL_COUNT += 1))
    else
        ((PASS_COUNT += 1))
    fi

    {
        printf '[%s] %s :: %s\n' "$result" "$image_name.sif" "$check_name"
        printf 'command: %s\n' "$quoted_command"
        printf 'exit_status: %s\n' "$status"
        printf 'expected_exit_status: %s\n' "$expected_status"
        printf 'expected_pattern: %s\n' "$expected_pattern"
        printf '%s\n' '--- output ---'
        printf '%s\n' "$output"
        printf '%s\n\n' '--- end output ---'
    } >>"$REPORT_TEMPORARY"
}

###############################################################################
# IMAGE CHECKS
###############################################################################

require_images() {
    local image_name

    for image_name in "${IMAGE_NAMES[@]}"; do
        [[ -f "$SCRIPT_DIR/$image_name.sif" ]] || \
            die "missing image: $SCRIPT_DIR/$image_name.sif"
    done
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    return 1
}

validate_external_boundaries() {
    record_check octopus external-model-boundary '^0$' \
        sh -c "find /opt /usr/local -type f \\( -iname '*.forest' -o -iname '*.model' \\) 2>/dev/null | wc -l"
    record_check deepvariant external-model-boundary '^0$' \
        sh -c "find /opt/models /opt/smallmodels -type f 2>/dev/null | wc -l"
    record_check annotation external-data-boundary '^0$' \
        sh -c "find /data /root/.vep /opt/vep -type f \\( -path '/data/*' -o -path '/root/.vep/*' -o -iname '*.fa' -o -iname '*.fasta' -o -iname '*.vcf' -o -iname '*.vcf.gz' \\) 2>/dev/null | wc -l"
}

write_checksums() {
    local temporary
    local image_name

    temporary="$(mktemp "$SCRIPT_DIR/.checksums.sha256.XXXXXX")"
    (
        cd -- "$SCRIPT_DIR"
        for image_name in "${IMAGE_NAMES[@]}"; do
            sha256sum "$image_name.sif"
        done
    ) >"$temporary"
    mv -- "$temporary" "$CHECKSUM_FILE"
}

###############################################################################
# MAIN
###############################################################################

main() {
    command -v apptainer >/dev/null 2>&1 || die 'apptainer is required'
    command -v sha256sum >/dev/null 2>&1 || die 'sha256sum is required'

    require_images
    REPORT_TEMPORARY="$(mktemp "$SCRIPT_DIR/.container_validation_report.XXXXXX")"
    write_header

    clinical_container_each_runtime_check record_check_status
    validate_external_boundaries
    write_checksums

    {
        printf 'SUMMARY\n'
        printf 'passed: %s\n' "$PASS_COUNT"
        printf 'failed: %s\n' "$FAIL_COUNT"
        if [[ $FAIL_COUNT -eq 0 ]]; then
            printf 'overall: PASS\n'
        else
            printf 'overall: FAIL\n'
        fi
    } >>"$REPORT_TEMPORARY"

    mv -- "$REPORT_TEMPORARY" "$REPORT_FILE"
    REPORT_TEMPORARY=''

    if [[ $FAIL_COUNT -ne 0 ]]; then
        printf 'FAIL: %s container validation check(s) failed; see %s\n' \
            "$FAIL_COUNT" "$REPORT_FILE" >&2
        return 1
    fi

    printf 'PASS: %s container validation checks; report: %s\n' \
        "$PASS_COUNT" "$REPORT_FILE"
}

main "$@"
