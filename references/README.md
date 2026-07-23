# External reference contract

ClinicalSuite does not download or redistribute reference genomes. A site must
provide one approved, checksum-locked GRCh38 bundle and mount it read-only.

## Expected contents

The final filenames are selected by the site profile and recorded in a manifest.
Deploy it as `REFERENCE_DIR/reference_manifest.tsv` using
`config/schemas/reference_manifest.schema.tsv`.
The following logical files are required:

| Logical item | Expected filename pattern | Version/compatibility requirement |
|---|---|---|
| GRCh38 FASTA | `GRCh38.fa` | One approved analysis set; sequence and contig set locked by SHA-256 |
| FASTA index | `GRCh38.fa.fai` | Generated from the exact FASTA with the pinned Samtools version |
| sequence dictionary | `GRCh38.dict` | Generated from the exact FASTA with the pinned Picard/GATK version |
| BWA-MEM2 indexes | `GRCh38.fa.*` | Generated from the exact FASTA with the pinned BWA-MEM2 version |
| dbSNP known sites | `dbsnp_GRCh38.vcf.gz` and `.tbi` | Site-approved release; GRCh38 contigs and REF alleles must match |
| known indels | `known_indels_GRCh38.vcf.gz` and `.tbi` | Site-approved GATK-compatible resource |
| Mills/1000G indels | `Mills_and_1000G_gold_standard.indels.GRCh38.vcf.gz` and `.tbi` | Site-approved GRCh38 release |
| PAR intervals | `GRCh38_PAR.bed` | Coordinates must match the selected FASTA and caller ploidy behavior |
| validation strata | `stratifications/*.bed.gz` | Versioned GIAB/GA4GH GRCh38 strata used only as declared |
| WES capture intervals | `assays/<ASSAY_ID>/capture.bed` | Exact manufacturer/laboratory capture design |
| WES reportable range | `assays/<ASSAY_ID>/reportable.bed` | Laboratory-approved clinical reportable range |

## Required manifest fields

Each item must record logical name, absolute deployment path, release/version,
assembly, contig naming convention, source provenance, SHA-256, index relationships,
license/access notes, approval state, and approval date.

Preflight reports all absent or incompatible items together and exits before
analysis. DeepVariant model directories are declared as
`DEEPVARIANT_MODEL_WGS`/`DEEPVARIANT_MODEL_WES` and remain external to SIFs.
Files placed here locally are ignored by git except for this README.
