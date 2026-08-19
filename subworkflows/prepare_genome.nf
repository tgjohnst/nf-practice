include { BUILD_STAR_INDEX } from '../modules/build_star_index'
include { BUILD_RSEM_REF   } from '../modules/build_rsem_ref'

workflow PREPARE_GENOME {
    take:
    fasta   // path
    gtf     // path

    main:
    // Global, one-time decision (not per-sample), so a plain Groovy `if` at
    // graph-construction time is the right tool -- no need to spin up a process
    // just to run `aws s3 ls`. file() resolves S3 paths natively.
    def star_marker = file("${params.star_index_bucket}/star_index/SAindex")
    def rsem_marker = file("${params.star_index_bucket}/rsem_ref/${params.rsem_ref_prefix}.n2g.idx.fa")

    if ( star_marker.exists() && rsem_marker.exists() ) {
        log.info "STAR/RSEM reference cache found at ${params.star_index_bucket} -- skipping build"
        star_index = Channel.fromPath("${params.star_index_bucket}/star_index", type: 'dir')
        rsem_ref   = Channel.fromPath("${params.star_index_bucket}/rsem_ref",   type: 'dir')
    } else {
        log.info "No cached reference found at ${params.star_index_bucket} -- building STAR index + RSEM reference"
        BUILD_STAR_INDEX(fasta, gtf)
        BUILD_RSEM_REF(fasta, gtf)
        star_index = BUILD_STAR_INDEX.out.index
        rsem_ref   = BUILD_RSEM_REF.out.ref_dir
    }

    emit:
    star_index
    rsem_ref
}
