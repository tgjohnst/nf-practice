include { PREPARE_GENOME } from './subworkflows/prepare_genome'
include { FASTP          } from './modules/fastp'
include { STAR_ALIGN     } from './modules/star_align'
include { RSEM_QUANT     } from './modules/rsem_quant'
include { MULTIQC        } from './modules/multiqc'

workflow {

    // Hand-rolled samplesheet parsing (vs. an nf-schema plugin) -- fine for a
    // practice pipeline; a schema-validation plugin would be the production upgrade.
    Channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true)
        .map { row -> tuple(row.sample, [file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true)]) }
        .set { ch_reads }

    fasta = file(params.fasta, checkIfExists: true)
    gtf   = file(params.gtf,   checkIfExists: true)

    PREPARE_GENOME(fasta, gtf)
    FASTP(ch_reads)

    // .first() converts the single-item reference channel into a value channel
    // so it can be reused across every sample instead of being consumed once.
    STAR_ALIGN(FASTP.out.trimmed, PREPARE_GENOME.out.star_index.first())
    RSEM_QUANT(STAR_ALIGN.out.transcriptome_bam, PREPARE_GENOME.out.rsem_ref.first())

    ch_multiqc_files = FASTP.out.json
        .mix(STAR_ALIGN.out.multiqc_logs)
        .mix(RSEM_QUANT.out.multiqc_logs)
        .collect()

    MULTIQC(ch_multiqc_files)
}
