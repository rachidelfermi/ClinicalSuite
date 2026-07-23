#!/usr/bin/env bash

set -Eeuo pipefail

###############################################################################
# CONFIGURATION
###############################################################################

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly BUILD_ROOT="$SCRIPT_DIR/.build"
readonly SOURCE_DIR="$BUILD_ROOT/sources"
readonly TEMP_DIR="$BUILD_ROOT/tmp"
readonly VALIDATION_SCRIPT="$SCRIPT_DIR/validate.sh"

readonly -a IMAGE_NAMES=(
    qc
    alignment
    gatk
    octopus
    deepvariant
    annotation
    report
)

###############################################################################
# USER INTERFACE
###############################################################################

print_usage() {
    cat <<'EOF'
Usage: containers/build.sh [OPTIONS] [IMAGE ...]

Build pinned ClinicalSuite Apptainer images. With no IMAGE argument, all images
are built in dependency-independent order and then validated.

Images:
  qc alignment gatk octopus deepvariant annotation report

Options:
  --list           Print supported image names and exit.
  --no-validate    Build without running container validation.
  --validate-only  Validate existing images without building.
  -h, --help       Show this help.
EOF
}

die() {
    printf 'ERROR: %s\n' "$1" >&2
    return 1
}

is_supported_image() {
    local requested="$1"
    local image

    for image in "${IMAGE_NAMES[@]}"; do
        [[ "$requested" == "$image" ]] && return 0
    done

    return 1
}

###############################################################################
# SOURCE ACQUISITION
###############################################################################

fetch_source() {
    local filename="$1"
    local url="$2"
    local expected_sha256="$3"
    local destination="$SOURCE_DIR/$filename"
    local temporary="$destination.part.$$"
    local actual_sha256

    if [[ -f "$destination" ]]; then
        actual_sha256="$(sha256sum "$destination" | awk '{print $1}')"
        if [[ "$actual_sha256" == "$expected_sha256" ]]; then
            printf 'SOURCE OK: %s\n' "$filename"
            return 0
        fi
        die "cached source checksum mismatch: $destination"
    fi

    printf 'FETCH: %s\n' "$url"
    curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
        --output "$temporary" "$url"

    actual_sha256="$(sha256sum "$temporary" | awk '{print $1}')"
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        rm -f -- "$temporary"
        die "source checksum mismatch for $filename"
    fi

    mv -- "$temporary" "$destination"
}

prepare_qc_sources() {
    fetch_source \
        fastqc_v0.12.1.zip \
        https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip \
        5f4dba8780231a25a6b8e11ab2c238601920c9704caa5458d9de559575d58aa7
    fetch_source \
        fastp.1.3.6 \
        https://opengene.org/fastp/fastp.1.3.6 \
        817df51647ecdacc1642daabe2438c744828ccda2d3634d90395ea91e3a7bc1f
    fetch_jre_source
}

prepare_alignment_sources() {
    fetch_source \
        bwa-mem2-2.3_x64-linux.tar.bz2 \
        https://github.com/bwa-mem2/bwa-mem2/releases/download/v2.3/bwa-mem2-2.3_x64-linux.tar.bz2 \
        112f3a3ebf3f8c2377f52d61446ead392c4a98ecf89e7629617d3ed16f4e73cb
    fetch_source \
        picard-3.4.0.jar \
        https://github.com/broadinstitute/picard/releases/download/3.4.0/picard.jar \
        e76128c283889fc583c9dea33a3b7448974c067d102c9e35be152642d4d5f901
    fetch_source \
        mosdepth-0.3.14 \
        https://github.com/brentp/mosdepth/releases/download/v0.3.14/mosdepth \
        c5182b74a8f1b66710efa16e122cbc8a197834874b103e7c5c0bd9a6265ae7b6
    fetch_jre_source
}

fetch_jre_source() {
    fetch_source \
        OpenJDK17U-jre_x64_linux_hotspot_17.0.19_10.tar.gz \
        https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.19%2B10/OpenJDK17U-jre_x64_linux_hotspot_17.0.19_10.tar.gz \
        adb5a2364baa51de1ef91bb9911f5a61d24b045fe1d6647cb8050272a3a8ee75
}

prepare_sources() {
    case "$1" in
        qc)
            prepare_qc_sources
            ;;
        alignment)
            prepare_alignment_sources
            ;;
        gatk|octopus|deepvariant|annotation|report)
            ;;
        *)
            die "unsupported image: $1"
            ;;
    esac
}

###############################################################################
# IMAGE BUILD
###############################################################################

build_image() {
    local image_name="$1"
    local definition="$SCRIPT_DIR/definitions/$image_name.def"
    local output="$SCRIPT_DIR/$image_name.sif"

    [[ -f "$definition" ]] || die "missing definition: $definition"
    prepare_sources "$image_name"

    printf '\nBUILD: %s.sif\n' "$image_name"
    APPTAINER_TMPDIR="$TEMP_DIR" apptainer build \
        --fakeroot \
        --force \
        --reproducible \
        "$output" \
        "$definition"
}

###############################################################################
# MAIN
###############################################################################

main() {
    local validate=true
    local validate_only=false
    local argument
    local -a selected_images=()

    while (( $# > 0 )); do
        argument="$1"
        shift

        case "$argument" in
            -h|--help)
                print_usage
                return 0
                ;;
            --list)
                printf '%s\n' "${IMAGE_NAMES[@]}"
                return 0
                ;;
            --no-validate)
                validate=false
                ;;
            --validate-only)
                validate_only=true
                ;;
            -* )
                die "unknown option: $argument"
                ;;
            *)
                is_supported_image "$argument" || \
                    die "unsupported image: $argument"
                selected_images+=("$argument")
                ;;
        esac
    done

    command -v apptainer >/dev/null 2>&1 || die 'apptainer is required'
    command -v sha256sum >/dev/null 2>&1 || die 'sha256sum is required'

    if [[ "$validate_only" == true ]]; then
        [[ ${#selected_images[@]} -eq 0 ]] || \
            die '--validate-only does not accept image names'
        exec "$VALIDATION_SCRIPT"
    fi

    if [[ ${#selected_images[@]} -eq 0 ]]; then
        selected_images=("${IMAGE_NAMES[@]}")
    fi

    command -v curl >/dev/null 2>&1 || die 'curl is required to build images'
    mkdir -p -- "$SOURCE_DIR" "$TEMP_DIR"
    cd -- "$SCRIPT_DIR"

    for argument in "${selected_images[@]}"; do
        build_image "$argument"
    done

    if [[ "$validate" == true ]]; then
        "$VALIDATION_SCRIPT"
    fi
}

main "$@"
