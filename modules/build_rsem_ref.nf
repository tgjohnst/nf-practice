process BUILD_RSEM_REF {
    tag "rsem_ref"
    label 'high_cpu'
    container 'quay.io/biocontainers/rsem:1.3.3--pl5321hecb563c_4'
    publishDir params.star_index_bucket, mode: 'copy'

    input:
    path fasta
    path gtf

    output:
    path 'rsem_ref', emit: ref_dir

    script:
    // No --star flag: RSEM would otherwise build its own redundant STAR index.
    // The standalone STAR_ALIGN process's transcriptome BAM is reused instead.
    """
    mkdir rsem_ref
    rsem-prepare-reference \\
        --gtf ${gtf} \\
        -p ${task.cpus} \\
        ${fasta} \\
        rsem_ref/${params.rsem_ref_prefix}
    """
}
