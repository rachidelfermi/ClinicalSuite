# ClinicalSuite V2

ClinicalSuite V2 is an incremental rebuild of a clinically oriented human
germline small-variant discovery framework for paired-end short-read WGS and WES.

## Current status

The repository skeleton, Module 2 configuration system, Module 3 common Bash
library, Module 4 container infrastructure, and Module 5 preflight validation are
implemented. No scientific workflow or clinical report is operational. Running
`./run.sh` without configuration exits clearly instead of attempting analysis.

This project is not a validated clinical assay or medical device. A laboratory
must perform end-to-end assay-specific validation and qualified expert review
before any clinical use.

## Supported scope

- Human nuclear germline SNVs and small indels
- WGS and hybrid-capture WES
- Illumina-compatible paired-end short reads
- Illumina and separately validated GeneMind assays
- GRCh38 only

Long reads, Oxford Nanopore, PacBio, somatic analysis, RNA-seq, methylation,
single-cell analysis, CNVs, structural variants, repeat expansions, and
mitochondrial variants are outside the initial V2 scope.

## Runtime contract

The eventual host runtime depends only on Bash and Apptainer. Scientific tools
will execute in pinned Apptainer images. Conda activation is not used at runtime,
and databases and reference genomes remain external and read-only.

No database or reference is bundled. Container SIFs are local deployment
artifacts built from the locked definitions in `containers/` and are excluded
from source control.

## Documentation

- [Architecture](Architecture.md)
- [Scientific decision record](docs/scientific-decisions.md)
- [Validation plan](docs/validation-plan.md)
- [Operations](docs/operations.md)
- [Implementation status](docs/implementation-status.md)
- [Reference contract](references/README.md)
- [Database contract](databases/README.md)
- [Container contract](containers/README.md)
- [Container provenance review](docs/container-provenance.md)
- [Configuration contract](config/README.md)
- [Common Bash library](bin/README.md)
- [Preflight contract](docs/preflight.md)

## Development order

Modules are implemented and validated one at a time:

1. Repository skeleton
2. Configuration system
3. Common Bash library
4. Container build system
5. Preflight
6. Quality control
7. Alignment and BAM processing
8. Coverage analysis
9. DeepVariant
10. GATK HaplotypeCaller
11. Octopus
12. Consensus engine
13. Variant filtering
14. Annotation
15. ACMG decision support
16. Reporting
17. Integration tests
18. End-to-end validation

Development must stop at any module whose validation fails.

## Skeleton check

```bash
./run.sh --help
bash tests/unit/test_run_interface.sh
bash tests/smoke/test_repository_skeleton.sh
```

## Configuration check

```bash
config/validate.sh --config clinical.conf --samples samples.tsv --check-only
bash tests/unit/test_configuration.sh
bash tests/smoke/test_configuration_system.sh
```

## Common-library check

```bash
bash tests/unit/test_common.sh
bash tests/integration/test_configuration_common.sh
bash tests/smoke/test_common_library.sh
```

## Preflight

```bash
./run.sh --config clinical.conf --samples samples.tsv --preflight-only
```
# ClinicalSuite
