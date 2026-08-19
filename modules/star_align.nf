process STAR_ALIGN {
    tag "$sample"
    label 'high_cpu'
    container 'quay.io/biocontainers/star:2.7.11b--h43eeafb_0'
    publishDir { "${params.outdir}/star/${sample}" }, mode: 'copy', pattern: '*.{out,tab}'

    input:
    tuple val(sample), path(reads)
    path star_index

    output:
    tuple val(sample), path("${sample}_Aligned.toTranscriptome.out.bam"), emit: transcriptome_bam
    path "${sample}_Log.final.out", emit: multiqc_logs

    script:
    // --outSAMtype BAM Unsorted + --quantMode TranscriptomeSAM is the flag pair RSEM needs:
    // Aligned.toTranscriptome.out.bam is read-grouped (not coordinate-sorted) and is what
    // rsem-calculate-expression --bam consumes directly, so no second alignment step is needed.
    """
    STAR \\
        --genomeDir ${star_index} \\
        --readFilesIn ${reads[0]} ${reads[1]} \\
        --readFilesCommand zcat \\
        --outSAMtype BAM Unsorted \\
        --quantMode TranscriptomeSAM \\
        --outFileNamePrefix ${sample}_ \\
        --runThreadN ${task.cpus} \\
        --outSAMunmapped Within
    """
}
