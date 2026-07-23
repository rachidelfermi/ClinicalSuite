# Apptainer container system

ClinicalSuite scientific executables run through seven immutable SIF deployment
artifacts. Docker is not used at runtime. Every upstream OCI reference and source
asset is pinned in `versions.lock`; floating tags are prohibited.

| Image | Runtime contents |
|---|---|
| `qc.sif` | FastQC 0.12.1, fastp 1.3.6, MultiQC 1.35 |
| `alignment.sif` | BWA-MEM2 2.3 release asset, Samtools/HTSlib 1.24, Picard 3.4.0, mosdepth 0.3.14 |
| `gatk.sif` | GATK 4.6.2.0, bcftools/HTSlib 1.24 |
| `octopus.sif` | Octopus 0.7.4; no forest/model |
| `deepvariant.sif` | Official DeepVariant 1.10.0 CPU runtime; no model files |
| `annotation.sif` | Ensembl VEP 116.0 runtime; no cache, plugins, or databases |
| `report.sif` | CPython 3.12.12 and locked HTML/tabular/plotting libraries |

## Build

Build all images and validate them:

```bash
./containers/build.sh
```

Build selected images without running the complete validation suite:

```bash
./containers/build.sh --no-validate qc alignment
```

Validate an existing complete image set:

```bash
./containers/build.sh --validate-only
```

Source archives are downloaded into ignored `containers/.build/` storage and
verified before use. SIFs are deployment artifacts and remain ignored by Git.
`checksums.sha256` contains the hashes of the locally built deployment set;
Apptainer OCI-to-SIF conversion metadata means independently converted SIFs can
have different byte hashes even when their locked OCI inputs are identical.

## External resources

References, databases, caches, plugins, and trained models must be mounted by
later runtime modules. The prepared empty paths are:

- DeepVariant standard models: `/opt/models`
- DeepVariant small models: `/opt/smallmodels`
- VEP external data: `/data`

No container in this module contains GRCh38, ClinVar, dbSNP, gnomAD, VEP cache,
CADD, REVEL, SpliceAI, dbNSFP, or an Octopus forest.

## Validation artifacts

- `lib.sh`: source-safe image list and executable/version check matrix shared by
  release validation and runtime preflight.
- `container_validation_report.txt`: command, expected/actual exit status, and
  captured output for every check.
- `checksums.sha256`: deployment SIF SHA-256 values.
- `versions.lock`: upstream versions, immutable sources, digests, and licenses.

The BWA-MEM2 v2.3 release asset retains the previous `2.2.1` embedded version
string. Validation records both the immutable v2.3 release asset checksum and the
actual reported string rather than concealing this upstream discrepancy.
