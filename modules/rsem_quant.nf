process RSEM_QUANT {
    tag "$sample"
    label 'mid_cpu'
    container 'quay.io/biocontainers/rsem:1.3.3--pl5321hecb563c_4'
    publishDir { "${params.outdir}/rsem/${sample}" }, mode: 'copy'

    input:
    tuple val(sample), path(transcriptome_bam)
    path rsem_ref_dir

    output:
    tuple val(sample), path("${sample}.genes.results"), path("${sample}.isoforms.results"), emit: results
    path "${sample}.stat", emit: multiqc_logs

    script:
    // --bam tells RSEM the input is a precomputed alignment (STAR's transcriptome BAM),
    // not raw reads; RSEM has no separate "--alignments" flag.
    """
    rsem-calculate-expression \\
        --paired-end \\
        --bam \\
        --no-bam-output \\
        -p ${task.cpus} \\
        ${transcriptome_bam} \\
        ${rsem_ref_dir}/${params.rsem_ref_prefix} \\
        ${sample}
    """
}
