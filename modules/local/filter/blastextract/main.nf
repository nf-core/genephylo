process FILTER_BLASTEXTRACT {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.1' :
        'quay.io/biocontainers/gawk:5.3.1' }"

    input:
    tuple val(meta), path(blastres)

    output:
    tuple val(meta), path("*_accessions.txt"), emit: accessions
    tuple val("${task.process}"), val("gawk"), eval("gawk --version | head -n 1 | cut -d',' -f1 | cut -d' ' -f3"), topic: versions, emit: versions_gawk

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    gawk -F'|' '{for (i=2; i<NF; i++) print \$i}' "${blastres}" > "${prefix}_accessions.txt"
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_accessions.txt
    """
}
