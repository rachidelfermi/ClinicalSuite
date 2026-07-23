# Container provenance review

Review date: 2026-07-21

## Selection boundary

Module 4 does not reconsider the approved scientific workflow. It packages the
tools already selected in `Architecture.md`, using current stable upstream
releases and immutable sources. Beta, nightly, and floating `latest` references
are excluded.

Upstream evidence reviewed:

- [Apptainer 1.5 definition and multi-stage build documentation](https://apptainer.org/user-docs/master/definition_files.html)
- [Apptainer OCI conversion documentation](https://apptainer.org/docs/user/latest/docker_and_oci.html)
- [MultiQC container guidance](https://docs.seqera.io/multiqc/getting_started/installation/)
- [BWA-MEM2 releases](https://github.com/bwa-mem2/bwa-mem2/releases)
- [Samtools releases](https://github.com/samtools/samtools/releases)
- [GATK releases and official images](https://github.com/broadinstitute/gatk/releases)
- [DeepVariant releases and official image guidance](https://github.com/google/deepvariant/releases)
- [Ensembl VEP container and external-cache documentation](https://www.ensembl.org/info/docs/tools/vep/script/vep_download.html)

The exact sources, digests, versions, and licenses are machine-readable in
`containers/versions.lock`.

## Packaging decisions

- The official MultiQC image is the QC base. FastQC, fastp, a minimal Java
  runtime, and the Perl modules required by the upstream FastQC launcher are
  added from pinned sources.
- The alignment image uses current Samtools/HTSlib 1.24 and the official
  BWA-MEM2 v2.3 release asset. A pinned runtime stage supplies only its C++
  libraries. Picard and mosdepth are installed from official release assets.
- The official GATK 4.6.2.0 image remains intact. Its bundled bcftools/HTSlib
  1.13 is superseded on `PATH` by a separately pinned 1.24 runtime because VCF
  normalization is a release-critical role and 1.24 is the current stable
  Samtools-family release.
- Octopus uses its pinned 0.7.4 BioContainer. No forest or model is present.
- DeepVariant is converted from the official stable CPU OCI image. Standard and
  small models inherited from that OCI image are removed; later modules must
  mount validated assay-specific models.
- VEP uses the official 116.0 image, matching the current Ensembl release.
  Caches, optional plugins, example VCFs, and test datasets are removed.
- The report image is deliberately small: Python plus a fully resolved set for
  templates, tables, and static plots. No reporting logic is implemented here.

## Known upstream behavior

The BWA-MEM2 v2.3 release archive has upstream SHA-256
`112f3a3ebf3f8c2377f52d61446ead392c4a98ecf89e7629617d3ed16f4e73cb`,
but `bwa-mem2 version` prints `2.2.1`. This was reproduced outside and inside the
container. The lock records v2.3 provenance while the validation report preserves
the actual embedded string.

Picard 3.4.0 and `run_deepvariant --help` return status 1 for the specific
introspection commands used here while producing the expected output. The
validator records and asserts those expected statuses explicitly.
