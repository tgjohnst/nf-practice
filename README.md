# nf-practice

A toy Nextflow DSL2 pipeline for bulk RNA-seq, built for interview practice.
Not production-ready — see [Before running for real](#before-running-for-real).

## Pipeline

```
                 ┌── (cached?) ──skip──┐
fasta, gtf ──▶ PREPARE_GENOME          ▼
                 └── build ──▶ STAR index + RSEM reference
                                        │
samplesheet ──▶ FASTP ──▶ STAR_ALIGN ──▶ RSEM_QUANT
                  │            │             │
                  └────────────┴─────────────┴──▶ MULTIQC
```

1. **PREPARE_GENOME** — checks `params.star_index_bucket` for an existing STAR index + RSEM
   reference (via marker files). Builds both with `BUILD_STAR_INDEX`/`BUILD_RSEM_REF` only if
   missing; otherwise reuses the cache. This check happens once at graph-construction time, not
   per sample.
2. **FASTP** — adapter/quality trimming per sample (paired-end).
3. **STAR_ALIGN** — splice-aware alignment against the STAR index, run with
   `--outSAMtype BAM Unsorted --quantMode TranscriptomeSAM` so it emits
   `Aligned.toTranscriptome.out.bam` directly — no separate alignment pass for RSEM.
4. **RSEM_QUANT** — gene/isoform quantification from the transcriptome BAM (`--bam`, no
   `--star`), against the shared RSEM reference.
5. **MULTIQC** — aggregates fastp JSON, STAR `Log.final.out`, and RSEM `.stat` logs into one
   report.

## Repository layout

```
main.nf                      top-level workflow: parses samplesheet, wires everything together
subworkflows/prepare_genome.nf   cache-or-build logic for the STAR index + RSEM reference
modules/                     one process per tool, flat (no modules/local/ nesting)
  build_star_index.nf
  build_rsem_ref.nf
  fastp.nf
  star_align.nf
  rsem_quant.nf
  multiqc.nf
conf/
  awsbatch.config            executor/region/S3 workDir for AWS Batch
  local.config                local executor + Docker, for smoke-testing the DAG
nextflow.config               params, resource-tier labels, profiles
assets/samplesheet.csv        example input (sample,fastq_1,fastq_2 schema)
```

## Requirements

- Nextflow `>=23.10.0`
- Docker (for the `local` profile) or an AWS Batch compute environment (for `awsbatch`)
- Reference FASTA + GTF, and an S3 bucket to hold/cache the STAR index and RSEM reference

## Input

A CSV samplesheet, paired-end only:

```csv
sample,fastq_1,fastq_2
sample1,s3://bucket/reads/sample1_R1.fastq.gz,s3://bucket/reads/sample1_R2.fastq.gz
sample2,s3://bucket/reads/sample2_R1.fastq.gz,s3://bucket/reads/sample2_R2.fastq.gz
```

See `assets/samplesheet.csv`. Parsing is hand-rolled `Channel.fromPath().splitCsv()` — there's no
schema-validation plugin here.

## Configuration

All real infra values in `nextflow.config` and `assets/samplesheet.csv` are `CHANGE-ME`
placeholders and must be set before a run will work — see
[Before running for real](#before-running-for-real).

Key params (`nextflow.config`):

| param | purpose |
|---|---|
| `input` | samplesheet CSV (required, no default) |
| `fasta` / `gtf` | reference genome FASTA / annotation GTF |
| `star_index_bucket` | S3 location holding (or to hold) `star_index/` and `rsem_ref/` |
| `rsem_ref_prefix` | RSEM reference basename inside `rsem_ref/` |
| `star_sjdb_overhang` | tune to `read_length - 1` |
| `outdir` | results output directory |
| `workdir_s3` | Nextflow's own S3 work directory (AWS Batch only) |
| `aws_batch_queue` / `aws_region` | AWS Batch queue name / region |

Resource tiers are set via `withLabel` in `nextflow.config`: `low_cpu` (2 CPU / 4 GB — fastp,
MultiQC), `mid_cpu` (8 CPU / 16 GB — RSEM quant), `high_cpu` (16 CPU / 64 GB — STAR indexing and
alignment).

## Running

Local smoke test (Docker, no AWS Batch needed):

```bash
nextflow run main.nf -profile local --input assets/samplesheet.csv
```

Full run on AWS Batch:

```bash
nextflow run main.nf -profile awsbatch --input assets/samplesheet.csv
```

## Output

Under `params.outdir` (default `./results`):

```
fastp/<sample>/       trimmed FASTQs, fastp JSON + HTML report
star/<sample>/        STAR *.out / *.tab logs (Log.final.out, SJ.out.tab, ...)
rsem/<sample>/        *.genes.results, *.isoforms.results
multiqc/              multiqc_report.html, multiqc_data/
```

The STAR index and RSEM reference are published to `params.star_index_bucket` (not `outdir`) so
later runs can reuse them.

## Before running for real

`params.fasta`, `params.gtf`, `params.star_index_bucket`, `params.workdir_s3`, and
`params.aws_batch_queue` in `nextflow.config` are `CHANGE-ME` placeholders — set them to real S3
paths and an actual AWS Batch queue before running. The example paths in
`assets/samplesheet.csv` need replacing too.
