# Preflight validation

`bin/preflight.sh` is the mandatory first runtime module. It validates inputs and
the execution environment, writes reports, and exits. It never starts scientific
analysis.

## Usage

```bash
bin/preflight.sh --config clinical.conf --samples samples.tsv
./run.sh --config clinical.conf --samples samples.tsv --preflight-only
```

Valid configuration writes to `RUN_ROOT/RUN_ID/preflight`; `--output-dir` can
override this location. Exit status is `0` for a pass, `69` for validation
failure, `64` for CLI misuse, and `1` if reports cannot be produced.

## External resource manifests

Preflight reads `REFERENCE_DIR/reference_manifest.tsv` and
`DATABASE_DIR/database_manifest.tsv`. Exact columns are defined in
`config/schemas/`. Paths may be absolute or relative to their resource root.
Files carry SHA-256 values; directories use `-`. Versions are pinned and genomic
resources declare `GRCh38`.

Mandatory reference IDs are `GRCH38_FASTA`, `GRCH38_FASTA_FAI`,
`GRCH38_SEQUENCE_DICTIONARY`, `BWA_MEM2_INDEX`, `GRCH38_PAR_INTERVALS`,
`KNOWN_INDELS`, `KNOWN_INDELS_INDEX`, `MILLS_INDELS`, `MILLS_INDELS_INDEX`, and
the assay-specific `DEEPVARIANT_MODEL_WGS`/`DEEPVARIANT_MODEL_WES`.

Mandatory database IDs are `CLINVAR`, `CLINVAR_INDEX`, `DBSNP`, `DBSNP_INDEX`,
`GNOMAD`, `GNOMAD_INDEX`, `VEP_CACHE`, `LOFTEE`, `SPLICEAI`,
`SPLICEAI_INDEX`, and `DBNSFP`. `REVEL` is optional and absent REVEL produces a
warning. Every additional manifest row marked `MANDATORY` is enforced. Database
rows record the compatible FASTA SHA-256.

## Validation and reports

Checks cover Module 2 inputs and resolved identity, Bash/utilities, Apptainer,
permissions, FASTQ structure/pair names, intervals, SIF checksums and executable
versions, external-resource checksums, GRCh38 compatibility, and disk space.
Container executable/version expectations come directly from
`containers/lib.sh`, the same matrix used by Module 4 release validation.
`MIN_RUN_FREE_GB`, `MIN_SCRATCH_FREE_GB`, and `DISK_SPACE_POLICY` control the
operational free-space gate.

Outputs are written atomically:

- `preflight_report.txt`: human-readable aggregated result;
- `preflight.json`: schema-versioned input for later modules;
- `preflight.log`: plain-text shared-library log.
