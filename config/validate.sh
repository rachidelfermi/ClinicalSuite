#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
# shellcheck source=config/parser.sh
source "$SCRIPT_DIR/parser.sh"

print_usage() {
    cat <<'EOF'
Usage: config/validate.sh --config FILE --samples FILE [OPTIONS]

Validate a ClinicalSuite clinical.conf and samples.tsv together. A successful
validation writes immutable normalized copies to RUN_ROOT/RUN_ID/resolved_config.

Options:
  --config FILE          Input clinical.conf (required)
  --samples FILE         Input samples.tsv (required)
  --resolved-dir DIR     Override the resolved output directory
  --check-only           Validate without writing resolved files
  -h, --help             Show this help
EOF
}

main() {
    local config_file=''
    local samples_file=''
    local resolved_directory=''
    local check_only=false

    while (( $# > 0 )); do
        case "$1" in
            --config) [[ $# -ge 2 ]] || { printf 'ERROR: --config requires a value\n' >&2; return 64; }; config_file="$2"; shift 2 ;;
            --samples) [[ $# -ge 2 ]] || { printf 'ERROR: --samples requires a value\n' >&2; return 64; }; samples_file="$2"; shift 2 ;;
            --resolved-dir) [[ $# -ge 2 ]] || { printf 'ERROR: --resolved-dir requires a value\n' >&2; return 64; }; resolved_directory="$2"; shift 2 ;;
            --check-only) check_only=true; shift ;;
            -h|--help) print_usage; return 0 ;;
            *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; return 64 ;;
        esac
    done

    [[ -n "$config_file" ]] || { printf 'ERROR: --config is required\n' >&2; return 64; }
    [[ -n "$samples_file" ]] || { printf 'ERROR: --samples is required\n' >&2; return 64; }

    if ! clinical_validate "$config_file" "$samples_file"; then
        clinical_print_errors >&2
        return 2
    fi

    if [[ "$check_only" == true ]]; then
        printf 'Configuration validation passed.\n'
        return 0
    fi

    if [[ -z "$resolved_directory" ]]; then
        resolved_directory="$RUN_DIR/resolved_config"
    elif [[ "$resolved_directory" != /* ]]; then
        resolved_directory="$(pwd -P)/$resolved_directory"
    fi
    if ! clinical_write_resolved "$resolved_directory"; then
        clinical_print_errors >&2
        return 2
    fi
    printf 'Configuration validation passed.\n'
    printf 'Resolved configuration: %s\n' "$CLINICAL_RESOLVED_CONFIG_DIR"
}

main "$@"
