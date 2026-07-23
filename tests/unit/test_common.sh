#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly TEST_DIR
REPOSITORY_ROOT="$(cd -- "$TEST_DIR/../.." && pwd -P)"
readonly REPOSITORY_ROOT
# shellcheck source=bin/common.sh
source "$REPOSITORY_ROOT/bin/common.sh"

TEST_ROOT="$(mktemp -d)"
readonly TEST_ROOT
trap 'chmod -R u+w "$TEST_ROOT" 2>/dev/null || true; rm -rf -- "$TEST_ROOT"' EXIT
CLINICAL_COLOR=never

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    return 1
}

assert_contains() {
    [[ "$1" == *"$2"* ]] || fail "output does not contain: $2"
}

assert_fails() {
    if "$@" >/dev/null 2>&1; then
        fail "command unexpectedly succeeded: $*"
    fi
}

test_initialization_and_logging() {
    local log_file="$TEST_ROOT/common.log" output

    common_init unit-test "$log_file" 0 1
    output="$({ log_info info; log_warning warning; log_error error; log_success success; log_debug debug; } 2>&1)"
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z ]] || \
        fail 'log timestamp is missing or malformed'
    assert_contains "$output" '[unit-test] INFO: info'
    assert_contains "$output" '[unit-test] WARNING: warning'
    assert_contains "$output" '[unit-test] ERROR: error'
    assert_contains "$output" '[unit-test] SUCCESS: success'
    assert_contains "$output" '[unit-test] DEBUG: debug'
    assert_contains "$(<"$log_file")" '[unit-test] DEBUG: debug'
    [[ "$(<"$log_file")" != *$'\033'* ]] || fail 'plain-text log contains ANSI escapes'

    common_init quiet-test "$log_file" 1 1
    output="$({ log_info hidden; log_success hidden; log_debug hidden; } 2>&1)"
    [[ -z "$output" ]] || fail 'quiet mode emitted routine terminal output'
    assert_contains "$(<"$log_file")" '[quiet-test] INFO: hidden'
    common_init nonverbose-test "$log_file" 0 0
    log_debug not-recorded 2>/dev/null
    [[ "$(<"$log_file")" != *not-recorded* ]] || fail 'debug was recorded without verbose mode'
    CLINICAL_COLOR=always
    output="$(log_error colored 2>&1)"
    [[ "$output" == *$'\033[31m'* ]] || fail 'forced terminal color was not emitted'
    CLINICAL_COLOR=never
    assert_fails common_init 'unsafe module' "$log_file"
}

test_errors_and_requirements() {
    local status

    common_init unit-test "$TEST_ROOT/common.log" 0 0
    warn 'nonfatal warning' 2>/dev/null
    require_file "$REPOSITORY_ROOT/VERSION"
    require_directory "$REPOSITORY_ROOT/bin"
    require_command bash
    assert_fails require_file "$TEST_ROOT/missing"
    assert_fails require_directory "$TEST_ROOT/missing-dir"
    assert_fails require_command clinicalsuite-command-that-does-not-exist
    set +e
    (die 'fatal test' 23) >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -eq 23 ]] || fail "die returned $status instead of 23"
}

test_temporary_paths_and_traps() {
    local temporary registered signal_status exit_temporary int_temporary

    create_temp_directory temporary "$TEST_ROOT" unit-temp
    [[ -d "$temporary" ]] || fail 'create_temp_directory did not create a directory'
    registered="$TEST_ROOT/registered"
    mkdir "$registered"
    register_cleanup "$registered"
    cleanup
    [[ ! -e "$temporary" && ! -e "$registered" ]] || fail 'cleanup left registered paths'
    assert_fails register_cleanup /

    temporary="$TEST_ROOT/trap-cleanup"
    set +e
    bash -c 'source "$1"; CLINICAL_COLOR=never; mkdir "$2"; register_cleanup "$2"; setup_cleanup_traps; kill -TERM $$' \
        bash "$REPOSITORY_ROOT/bin/common.sh" "$temporary" >/dev/null 2>&1
    signal_status=$?
    set -e
    [[ $signal_status -eq 143 ]] || fail "SIGTERM trap returned $signal_status"
    [[ ! -e "$temporary" ]] || fail 'signal trap did not clean registered path'

    int_temporary="$TEST_ROOT/int-cleanup"
    set +e
    bash -c 'source "$1"; CLINICAL_COLOR=never; mkdir "$2"; register_cleanup "$2"; setup_cleanup_traps; kill -INT $$' \
        bash "$REPOSITORY_ROOT/bin/common.sh" "$int_temporary" >/dev/null 2>&1
    signal_status=$?
    set -e
    [[ $signal_status -eq 130 ]] || fail "SIGINT trap returned $signal_status"
    [[ ! -e "$int_temporary" ]] || fail 'SIGINT trap did not clean registered path'

    exit_temporary="$TEST_ROOT/exit-cleanup"
    bash -c 'source "$1"; mkdir "$2"; register_cleanup "$2"; setup_cleanup_traps' \
        bash "$REPOSITORY_ROOT/bin/common.sh" "$exit_temporary"
    [[ ! -e "$exit_temporary" ]] || fail 'EXIT trap did not clean registered path'
}

test_filesystem_and_checkpoints() {
    local directory="$TEST_ROOT/files with spaces" source copied moved atomic marker provenance digest
    local writer_status

    create_directory "$directory" 0750
    [[ "$(stat -c '%a' "$directory")" == 750 ]] || fail 'create_directory mode is wrong'
    source="$directory/source.txt"
    copied="$directory/copied.txt"
    moved="$directory/moved.txt"
    atomic="$directory/atomic.txt"
    printf 'source-data\n' >"$source"
    safe_copy "$source" "$copied"
    [[ "$(<"$copied")" == source-data ]] || fail 'safe_copy changed content'
    assert_fails safe_copy "$source" "$copied"
    safe_move "$copied" "$moved"
    [[ ! -e "$copied" && -f "$moved" ]] || fail 'safe_move failed'
    printf 'first\n' | atomic_write "$atomic" 0600
    printf 'second\n' | atomic_write "$atomic" 0600
    [[ "$(<"$atomic")" == second ]] || fail 'atomic_write did not publish complete content'
    set +e
    atomic_write "$atomic" 0600 -- bash -c 'printf partial; exit 9' >/dev/null 2>&1
    writer_status=$?
    set -e
    [[ $writer_status -eq 9 ]] || fail 'atomic_write lost writer failure status'
    [[ "$(<"$atomic")" == second ]] || fail 'atomic_write published partial content'

    digest="$(calculate_checksum "$source")"
    marker="$directory/module.complete"
    provenance="$directory/provenance.txt"
    printf 'command_sha256=%s\nsignature=%064d\n' "$digest" 1 >"$provenance"
    create_complete_marker "$marker" "$digest" "$provenance"
    check_complete_marker "$marker" "$digest"
    assert_fails check_complete_marker "$marker" "${digest/0/1}"
    assert_contains "$(<"$marker")" 'provenance_begin'
}

create_mock_command() {
    local path="$1"

    cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -u
counter_file="$1"
count=0
[[ ! -f "$counter_file" ]] || IFS= read -r count <"$counter_file"
count=$((count + 1))
printf '%s\n' "$count" >"$counter_file"
printf 'attempt-%s\n' "$count"
printf 'diagnostic-%s\n' "$count" >&2
(( count >= 2 ))
EOF
    chmod +x "$path"
}

create_mock_apptainer() {
    local path="$1"

    cat >"$path" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >"${MOCK_APPTAINER_ARGS:?}"
if [[ "${1:-}" == --version ]]; then
    printf 'apptainer version mock-1.0\n'
    exit 0
fi
while (( $# > 0 )); do
    case "$1" in
        exec|--cleanenv|--containall|--no-home|--net) shift ;;
        --pwd|--bind|--network) shift 2 ;;
        *) shift; break ;;
    esac
done
"$@"
EOF
    chmod +x "$path"
}

test_command_and_container_execution() {
    local mock="$TEST_ROOT/mock-command.sh" counter="$TEST_ROOT/counter"
    local stdout_file="$TEST_ROOT/stdout" stderr_file="$TEST_ROOT/stderr"
    local apptainer="$TEST_ROOT/apptainer" image="$TEST_ROOT/image.sif"
    local arguments_file="$TEST_ROOT/apptainer.args" output status bind_directory="$TEST_ROOT/bind with spaces"

    create_mock_command "$mock"
    run_command --retries 1 --retry-delay 0 --timing --stdout "$stdout_file" \
        --stderr "$stderr_file" -- "$mock" "$counter"
    [[ "$RUN_COMMAND_STATUS" -eq 0 ]] || fail 'run_command did not capture success status'
    [[ "$RUN_COMMAND_ELAPSED_SECONDS" =~ ^[0-9]+$ ]] || fail 'run_command timing is malformed'
    [[ "$(<"$stdout_file")" == attempt-2 ]] || fail 'run_command captured wrong stdout'
    [[ "$(<"$stderr_file")" == diagnostic-2 ]] || fail 'run_command captured wrong stderr'

    set +e
    run_command -- bash -c 'printf failure >&2; exit 7' >/dev/null 2>&1
    status=$?
    set -e
    [[ $status -eq 7 && $RUN_COMMAND_STATUS -eq 7 ]] || fail 'run_command lost failure status'

    create_mock_apptainer "$apptainer"
    : >"$image"
    mkdir "$bind_directory"
    export MOCK_APPTAINER_ARGS="$arguments_file"
    output="$(run_container --apptainer "$apptainer" --bind-ro "$bind_directory" /inputs \
        "$image" -- printf 'container-ok\n')"
    [[ "$output" == container-ok ]] || fail 'run_container did not execute the command'
    assert_contains "$(<"$arguments_file")" '--cleanenv --containall --no-home --pwd / --net --network none'
    assert_contains "$(<"$arguments_file")" "$bind_directory:/inputs:ro"
    assert_fails run_container --apptainer "$apptainer" "$TEST_ROOT/missing.sif" -- true
    assert_fails run_command --retries
    assert_fails run_container --bind-ro only-one-value
}

test_structural_validation_and_checksums() {
    local fastq="$TEST_ROOT/valid.fastq" fastq_gz="$TEST_ROOT/valid.fastq.gz"
    local bam="$TEST_ROOT/valid.bam" vcf="$TEST_ROOT/valid.vcf" vcf_gz="$TEST_ROOT/valid.vcf.gz"
    local index="$TEST_ROOT/valid.vcf.gz.tbi" digest

    printf '@read\nACGT\n+\n!!!!\n' >"$fastq"
    gzip -c "$fastq" >"$fastq_gz"
    check_fastq "$fastq"
    check_fastq "$fastq_gz"
    printf 'invalid\n' >"$TEST_ROOT/invalid.fastq"
    assert_fails check_fastq "$TEST_ROOT/invalid.fastq"

    printf 'BAM\001payload' | gzip -c >"$bam"
    check_bam "$bam"
    printf 'not-bam' | gzip -c >"$TEST_ROOT/invalid.bam"
    assert_fails check_bam "$TEST_ROOT/invalid.bam"

    printf '##fileformat=VCFv4.3\n#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\n' >"$vcf"
    gzip -c "$vcf" >"$vcf_gz"
    check_vcf "$vcf"
    check_vcf "$vcf_gz"
    printf 'index\n' >"$index"
    check_index "$vcf_gz" "$index"
    digest="$(calculate_checksum "$vcf")"
    check_checksum "$vcf" "$digest"
    assert_fails check_checksum "$vcf" "${digest/0/1}"
}

test_versions_environment_progress_timing_and_config() {
    local version environment_file="$TEST_ROOT/environment.txt" output elapsed
    local elapsed_file="$TEST_ROOT/elapsed.txt"
    local apptainer="$TEST_ROOT/apptainer-version" image="$TEST_ROOT/version.sif"

    version="$(get_tool_version bash --version)"
    assert_contains "$version" 'GNU bash'
    [[ "$(get_pipeline_version "$REPOSITORY_ROOT/VERSION")" == 2.0.0-dev ]] || \
        fail 'pipeline version is wrong'

    create_mock_apptainer "$apptainer"
    : >"$image"
    export MOCK_APPTAINER_ARGS="$TEST_ROOT/version.args"
    declare -ga CLINICAL_CONFIG_KEYS=(APPTAINER_BIN THREADS EMPTY_VALUE)
    declare -gA CLINICAL_CONFIG=(
        [APPTAINER_BIN]="$apptainer"
        [THREADS]=8
        [EMPTY_VALUE]=''
    )
    [[ "$(config_get THREADS)" == 8 ]] || fail 'config_get returned wrong value'
    [[ "$(config_require APPTAINER_BIN)" == "$apptainer" ]] || fail 'config_require failed'
    assert_fails config_get UNKNOWN
    assert_fails config_require EMPTY_VALUE
    output="$(get_container_version "$image" printf 'container-version-1\n')"
    [[ "$output" == container-version-1 ]] || fail 'get_container_version failed'

    report_environment "$environment_file"
    assert_contains "$(<"$environment_file")" 'hostname='
    assert_contains "$(<"$environment_file")" 'operating_system='
    assert_contains "$(<"$environment_file")" 'apptainer_version=apptainer version mock-1.0'
    output="$(report_progress 3 10 Alignment 2>&1)"
    assert_contains "$output" '[3/10] Alignment'
    assert_fails report_progress 11 10 invalid

    start_timer module-timer
    CLINICAL_TIMERS[module-timer]=$((SECONDS - 2))
    stop_timer module-timer >"$elapsed_file" 2>/dev/null
    elapsed="$(<"$elapsed_file")"
    [[ "$elapsed" -ge 2 ]] || fail 'timer elapsed value is wrong'
    [[ "$TIMER_ELAPSED_SECONDS" -ge 2 ]] || fail 'timer result state is wrong'
    assert_fails stop_timer module-timer
}

main() {
    test_initialization_and_logging
    test_errors_and_requirements
    test_temporary_paths_and_traps
    test_filesystem_and_checkpoints
    test_command_and_container_execution
    test_structural_validation_and_checksums
    test_versions_environment_progress_timing_and_config
    cleanup
    printf 'PASS: common Bash library unit tests\n'
}

main "$@"
