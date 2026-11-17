# nf-core/genephylo: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0dev - [unreleased<!-- TODO nf-core: replace with date on release -->]

Initial release of nf-core/genephylo, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- [#10](https://github.com/nf-core/genephylo/pull/10) - Build the ETE3 taxonomy database only once per run, and add `--taxdump` to provide the NCBI taxdump locally (@charles-plessy)
- [#20](https://github.com/nf-core/genephylo/pull/20) - Local module to clean FASTA headers after the initial MAFFT alignment (@leapicard)
- [#22](https://github.com/nf-core/genephylo/pull/22) - Local gawk module to select the longest ORF and rename sequences (replacing `TD2_PREDICT`); FastTree and TreeRecs added to the pipeline (@leapicard)
- [#23](https://github.com/nf-core/genephylo/pull/23) - Orthogroup separation, selection and extraction; realignment with MAFFT, final codon-aware alignment with MACSE and final phylogeny with IQ-TREE (@leapicard)

### `Changed`

- [#24](https://github.com/nf-core/genephylo/pull/24) - ETE modules report their version in the software versions report and use the Singularity image with Apptainer (@pmuskusv)
- [#29](https://github.com/nf-core/genephylo/pull/29) - BLAST database preparation moved into the local subworkflow `PREPARE_BLASTDB` (@pmuskusv)

### `Fixed`

- [#28](https://github.com/nf-core/genephylo/pull/28) - `ETE_TAXDB` now builds the taxonomy database from `--taxdump` when given, instead of always downloading it (@pmuskusv)

### `Dependencies`

- [#16](https://github.com/nf-core/genephylo/pull/16), [#18](https://github.com/nf-core/genephylo/pull/18), [#26](https://github.com/nf-core/genephylo/pull/26) - Updated pipeline template to [nf-core/tools 4.2.2](https://github.com/nf-core/tools/releases/tag/4.2.2) (minimum Nextflow `26.04.0`, nf-schema `3.0.0`)

### `Deprecated`

- Removed `--hook_url` (Slack/Teams notifications), following the nf-core template
