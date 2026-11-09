process SED_CLEANFASTAIDS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:24.04' :
        'nf-core/ubuntu:24.04' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.fasta"), emit: fasta
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}_clean"
    // Suffix added by TD2 to ORF ids (e.g. ".p1", ".p2"); can be overridden with ext.args
    def suffix = task.ext.args ?: '\\.p[0-9]+'
    """
    sed -E '/^>/{ s/[[:space:]].*\$//; s/${suffix}\$//; }' ${fasta} > ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(sed --version 2>&1 | head -n 1 | sed 's/^.*) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}_clean"
    """
    touch ${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(sed --version 2>&1 | head -n 1 | sed 's/^.*) //')
    END_VERSIONS
    """
}
