# HG002 QC test fixture

This directory contains a small, real human whole-genome sequencing fixture for
ClinicalSuite unit, integration, and smoke tests. It is not suitable for
scientific benchmarking, analytical validation, variant assessment, or any
clinical use.

## Source

- Sample: Genome in a Bottle HG002 / NA24385 (Ashkenazim son)
- Accession: NCBI BioSample `SAMN03283347` (SRA sample `SRS817069`)
- Dataset: NIST Illumina PCR-free paired-end 2 x 250 bp WGS
- Source metadata:
  <https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/README_NIST_Illumina_pairedend_2x250_HG002.txt>
- R1 source:
  <https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/reads/D1_S1_L001_R1_004.fastq.gz>
- R2 source:
  <https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/data/AshkenazimTrio/HG002_NA24385_son/NIST_Illumina_2x250bps/reads/D1_S1_L001_R2_004.fastq.gz>

Reference publication:

> Zook JM, et al. Extensive sequencing of seven human genomes to characterize
> benchmark reference materials. *Scientific Data*. 2016;3:160025.
> <https://doi.org/10.1038/sdata.2016.25>

## Subset generation

`HG002_test_R1.fastq.gz` and `HG002_test_R2.fastq.gz` each contain exactly
50,000 reads (50,000 read pairs total; 100,000 individual reads). They are the
first 50,000 synchronized pairs in source chunk `D1_S1_L001_*_004.fastq.gz`.
No read sampling, trimming, filtering, or sequence modification was performed.
The original four-line FASTQ records are retained and recompressed with a gzip
timestamp of zero.

The generator reads both HTTP gzip streams together, validates every FASTQ
record and mate identifier, and closes the streams after the requested pair
count. It therefore does not download the complete WGS files.

Reproduce the fixture from the repository root:

```bash
python3 tests/data/fastq/create_subset.py --pairs 50000
(cd tests/data/fastq && sha256sum --check SHA256SUMS)
```

## Integrity and record counts

| File | Read records | Uncompressed lines | SHA-256 |
| --- | ---: | ---: | --- |
| `HG002_test_R1.fastq.gz` | 50,000 | 200,000 | `40b001203ed6582994692e75af64a7b06600de96141ec462c5968527a3d1209f` |
| `HG002_test_R2.fastq.gz` | 50,000 | 200,000 | `d3fd947f0fdc7656df9f47a69728c1aeb40f02448625a8c51e4b3e2f31351421` |

Validate record counts with:

```bash
for file in tests/data/fastq/HG002_test_R{1,2}.fastq.gz; do
    printf '%s: ' "$file"
    gzip -cd "$file" | awk 'END { print NR / 4 " reads" }'
done
```

No reference genome, annotation database, VEP cache, GIAB truth set, or trained
model is included or retrieved by the generator.
