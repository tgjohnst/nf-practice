process FASTP {
    tag "$sample"
    label 'low_cpu'
    container 'quay.io/biocontainers/fastp:0.23.4--h5f740d0_0'
    publishDir "${params.outdir}/fastp/${sample}", mode: 'copy'

    input:
    tuple val(sample), path(reads)

    output:
    tuple val(sample), path("${sample}_R{1,2}.trim.fastq.gz"), emit: trimmed
    path "${sample}.fastp.json", emit: json
    path "${sample}.fastp.html"

    script:
    """
    fastp \\
        -i ${reads[0]} -I ${reads[1]} \\
        -o ${sample}_R1.trim.fastq.gz -O ${sample}_R2.trim.fastq.gz \\
        -j ${sample}.fastp.json -h ${sample}.fastp.html \\
        -w ${task.cpus}
    """
}
