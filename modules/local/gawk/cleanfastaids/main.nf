process GAWK_CLEANFASTAIDS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.1' :
        'quay.io/biocontainers/gawk:5.3.1' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.fasta"), emit: fasta
    tuple val("${task.process}"), val("gawk"), eval("gawk --version | head -n 1 | cut -d',' -f1 | cut -d' ' -f3"), topic: versions, emit: versions_gawk

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}_clean"
    // Suffix added by TD2 to ORF ids (e.g. ".p1", ".p2"); can be overridden with ext.args
    def suffix = task.ext.args ?: '\\.p[0-9]+'
    """
    gawk '/^>/ { sub(/[[:space:]].*\$/, ""); sub(/${suffix}\$/, "") } 1' ${fasta} > ${prefix}.fasta
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}_clean"
    """
    touch ${prefix}.fasta
    """
}
