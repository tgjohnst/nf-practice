process BUILD_STAR_INDEX {
    tag "star_index"
    label 'high_cpu'
    container 'quay.io/biocontainers/star:2.7.11b--h43eeafb_0'
    publishDir params.star_index_bucket, mode: 'copy'

    input:
    path fasta
    path gtf

    output:
    path 'star_index', emit: index

    script:
    """
    mkdir star_index
    STAR \\
        --runMode genomeGenerate \\
        --genomeDir star_index \\
        --genomeFastaFiles ${fasta} \\
        --sjdbGTFfile ${gtf} \\
        --sjdbOverhang ${params.star_sjdb_overhang} \\
        --runThreadN ${task.cpus}
    """
}
