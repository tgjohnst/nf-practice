# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository status

This repository is a scratch space for practicing Nextflow pipeline development (interview prep). It currently holds a single DSL2 bulk RNA-seq pipeline: **fastp → STAR (splice-aware alignment) → RSEM (gene/isoform quantification) → MultiQC**, targeting AWS Batch in `us-west-2`.

## Architecture

- `main.nf` — top-level `workflow {}`. Parses the samplesheet, then wires `PREPARE_GENOME` → `FASTP` → `STAR_ALIGN` → `RSEM_QUANT` → `MULTIQC`.
- `subworkflows/prepare_genome.nf` — the one non-trivial piece of control flow: checks whether a STAR index + RSEM reference already exist at `params.star_index_bucket` (via `file(...).exists()` on marker files, evaluated once at graph-construction time, not a per-sample channel branch) and only runs `BUILD_STAR_INDEX`/`BUILD_RSEM_REF` if the cache is missing. Both are cached together in the same S3 location so neither is rebuilt on repeat runs.
- `modules/*.nf` — one process per tool (`build_star_index`, `build_rsem_ref`, `fastp`, `star_align`, `rsem_quant`, `multiqc`). Flat, no `modules/local/` nesting — there's no remote-module sharing here.
- STAR is run with `--outSAMtype BAM Unsorted --quantMode TranscriptomeSAM`; this is what makes `Aligned.toTranscriptome.out.bam` consumable directly by `rsem-calculate-expression --bam` — there is no second alignment step. If either of those two STAR flags changes, RSEM's `--bam` input breaks.
- The single-item reference channels emitted by `PREPARE_GENOME` (`star_index`, `rsem_ref`) are turned into value channels with `.first()` before being passed into the per-sample `STAR_ALIGN`/`RSEM_QUANT` calls in `main.nf` — without it, only the first sample would get the reference.
- `nextflow.config` — `params` (all real infra values — S3 buckets, AWS Batch queue — are `CHANGE-ME` placeholders, not real), 3 `withLabel` resource tiers (`low_cpu`/`mid_cpu`/`high_cpu`), `profiles { awsbatch, local }`.
- `conf/awsbatch.config` / `conf/local.config` — executor-specific settings, pulled in via profile. `awsbatch` sets `process.executor`, `aws.region`, and points `workDir` at an S3 path (AWS Batch tasks have no shared local filesystem). `local` is for smoke-testing the DAG with Docker before trusting it on Batch.
- Samplesheet input is hand-rolled `Channel.fromPath().splitCsv()` (see `assets/samplesheet.csv` for the `sample,fastq_1,fastq_2` schema), not a schema-validation plugin — paired-end only for now.

## Before running for real

`params.fasta`, `params.gtf`, `params.star_index_bucket`, `params.workdir_s3`, and `params.aws_batch_queue` in `nextflow.config` are placeholders (`CHANGE-ME-...`) and must be filled in with real S3 paths / an actual AWS Batch queue name before a run will work.
