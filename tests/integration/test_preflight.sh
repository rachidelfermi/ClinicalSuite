#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly TEST_DIR
REPOSITORY_ROOT="$(cd -- "$TEST_DIR/../.." && pwd -P)"
readonly REPOSITORY_ROOT
readonly PREFLIGHT="$REPOSITORY_ROOT/bin/preflight.sh"
# shellcheck source=tests/helpers/preflight_fixture.sh
source "$REPOSITORY_ROOT/tests/helpers/preflight_fixture.sh"

TEST_ROOT="$(mktemp -d)"
readonly TEST_ROOT
trap 'chmod -R u+w "$TEST_ROOT" 2>/dev/null || true; rm -rf -- "$TEST_ROOT"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    return 1
}

run_failure_case() {
    local root="$1"
    local expected="$2"
    local status

    set +e
    "$PREFLIGHT" --config "$root/clinical.conf" --samples "$root/samples.tsv" \
        --output-dir "$root/preflight-output" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -eq 69 ]] || fail "expected preflight status 69, found $status"
    grep -Eqi -- "$expected" "$root/preflight-output/preflight_report.txt" ||
        fail "report does not contain expected failure: $expected"
    jq -e '.status == "FAIL" and .error_count > 0' \
        "$root/preflight-output/preflight.json" >/dev/null || fail 'failure JSON is invalid'
}

test_success() {
    local root="$TEST_ROOT/success"

    preflight_fixture_create "$root" WGS
    "$PREFLIGHT" --config "$root/clinical.conf" --samples "$root/samples.tsv" \
        --output-dir "$root/preflight-output" >/dev/null
    jq -e '.status == "PASS" and .error_count == 0' \
        "$root/preflight-output/preflight.json" >/dev/null || fail 'success JSON is invalid'
    [[ -r "$root/runs/RUN_001/resolved_config/clinical.conf" ]] ||
        fail 'resolved configuration was not created'
    "$REPOSITORY_ROOT/run.sh" --config "$root/clinical.conf" --samples "$root/samples.tsv" \
        --preflight-dir "$root/run-preflight" --preflight-only >/dev/null
}

test_missing_fastq() {
    local root="$TEST_ROOT/missing-fastq"

    preflight_fixture_create "$root" WGS
    mv "$root/data/sample_R2.fastq.gz" "$root/data/removed_R2.fastq.gz"
    run_failure_case "$root" 'Missing FASTQ|fastq_r2'
}

test_missing_container() {
    local root="$TEST_ROOT/missing-container"

    preflight_fixture_create "$root" WGS
    mv "$root/containers/qc.sif" "$root/containers/qc.sif.missing"
    run_failure_case "$root" 'Missing container:.*qc\.sif'
}

test_missing_database() {
    local root="$TEST_ROOT/missing-database"

    preflight_fixture_create "$root" WGS
    mv "$root/databases/clinvar.vcf.gz" "$root/databases/clinvar.missing"
    run_failure_case "$root" 'Mandatory resource missing.*CLINVAR'
}

test_unreadable_fastq() {
    local root="$TEST_ROOT/unreadable-fastq"

    preflight_fixture_create "$root" WGS
    chmod 000 "$root/data/sample_R1.fastq.gz"
    run_failure_case "$root" 'Invalid path|Unreadable.*FASTQ|fastq_r1'
    chmod 0600 "$root/data/sample_R1.fastq.gz"
}

test_invalid_permissions() {
    local root="$TEST_ROOT/permissions"

    preflight_fixture_create "$root" WGS
    chmod 0550 "$root/scratch"
    run_failure_case "$root" 'not writable|SCRATCH_DIR'
    chmod 0750 "$root/scratch"
}

test_malformed_configuration() {
    local root="$TEST_ROOT/malformed"

    preflight_fixture_create "$root" WGS
    printf 'REFERENCE_PATH=unknown\n' >>"$root/clinical.conf"
    run_failure_case "$root" 'Unknown key|REFERENCE_PATH'
}

test_incompatible_reference() {
    local root="$TEST_ROOT/incompatible-reference"

    preflight_fixture_create "$root" WGS
    printf '>chr2\nACGT\n' >"$root/references/GRCh38.fa"
    run_failure_case "$root" 'Reference indexes are inconsistent|Checksum mismatch: GRCH38_FASTA'
}

test_aggregated_failures() {
    local root="$TEST_ROOT/aggregated"
    local status report

    preflight_fixture_create "$root" WGS
    mv "$root/containers/qc.sif" "$root/containers/qc.sif.missing"
    mv "$root/databases/clinvar.vcf.gz" "$root/databases/clinvar.missing"
    set +e
    "$PREFLIGHT" --config "$root/clinical.conf" --samples "$root/samples.tsv" \
        --output-dir "$root/preflight-output" >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -eq 69 ]] || fail "aggregate case returned $status"
    report="$(<"$root/preflight-output/preflight_report.txt")"
    [[ "$report" == *'Missing container:'*qc.sif* ]] ||
        fail 'aggregate report omitted missing container'
    [[ "$report" == *'Mandatory resource missing or unreadable: CLINVAR'* ]] ||
        fail 'aggregate report omitted missing database'
}

main() {
    test_success
    test_missing_fastq
    test_missing_container
    test_missing_database
    test_unreadable_fastq
    test_invalid_permissions
    test_malformed_configuration
    test_incompatible_reference
    test_aggregated_failures
    printf 'PASS: preflight integration tests\n'
}

main "$@"
