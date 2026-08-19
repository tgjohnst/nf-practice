process MULTIQC {
    label 'low_cpu'
    container 'quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0'
    publishDir "${params.outdir}/multiqc", mode: 'copy'

    input:
    path '*'

    output:
    path 'multiqc_report.html'
    path 'multiqc_data'

    script:
    """
    multiqc .
    """
}
