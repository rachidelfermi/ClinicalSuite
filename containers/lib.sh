#!/usr/bin/env bash
# Source-safe runtime validation contract shared by container build and preflight.

if [[ "${CLINICAL_CONTAINER_LIBRARY_LOADED:-0}" == 1 ]]; then
    return 0 2>/dev/null || exit 0
fi
readonly CLINICAL_CONTAINER_LIBRARY_LOADED=1

# Public deployment set consumed by validation and preflight.
# shellcheck disable=SC2034
readonly -a CLINICAL_CONTAINER_IMAGES=(
    qc
    alignment
    gatk
    octopus
    deepvariant
    annotation
    report
)

# The callback receives image, check name, expected regex, expected status, then
# the exact in-container command. Keeping this matrix here prevents preflight and
# release validation from drifting apart.
clinical_container_each_runtime_check() {
    local callback="$1"

    "$callback" qc FastQC '0\.12\.1' 0 fastqc --version
    "$callback" qc fastp '1\.3\.6' 0 fastp --version
    "$callback" qc MultiQC '1\.35' 0 multiqc --version
    # The upstream v2.3 asset retains the prior embedded version string.
    "$callback" alignment BWA-MEM2 '2\.2\.1' 0 bwa-mem2 version
    "$callback" alignment Samtools '^samtools 1\.24' 0 samtools --version
    "$callback" alignment Picard '^Version:3\.4\.0$' 1 \
        picard MarkDuplicates --version
    "$callback" alignment mosdepth '0\.3\.14' 0 mosdepth --version
    "$callback" gatk GATK 'v?4\.6\.2\.0' 0 gatk --version
    "$callback" gatk bcftools '^bcftools 1\.24' 0 bcftools --version
    "$callback" gatk htslib 'htslib.*1\.24' 0 htsfile --version
    "$callback" octopus Octopus 'octopus version 0\.7\.4' 0 octopus --version
    "$callback" octopus Octopus-help 'octopus' 0 octopus --help
    "$callback" deepvariant DeepVariant 'Runs all 3 steps' 1 run_deepvariant --help
    "$callback" annotation VEP 'ensembl-vep[[:space:]]*: 116\.0' 0 vep --help
    "$callback" report Python '^Python 3\.12\.12' 0 python --version
    "$callback" report reporting-libraries '^imports-ok$' 0 \
        python -c 'import jinja2, matplotlib, pandas; print("imports-ok")'
}
