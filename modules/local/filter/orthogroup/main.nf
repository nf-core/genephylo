process FILTER_ORTHOGROUP {
    tag "${meta.id}"
    label 'process_single'

    // python only: select_orthogroup.py (bin/) relies on the standard library alone
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a3/a3afdbbeb3c6f212ac595eca51a566b047a7bab2c50783955d3aac0d55fa683b/data' :
        'community.wave.seqera.io/library/python:3.10.4--b5b45c494792cf95' }"

    input:
    tuple val(meta), path(recphyloxml)

    output:
    tuple val(meta), path("*_orthogroup_ids.txt"), emit: ids
    tuple val(meta), path("*_orthogroup.log")    , emit: log
    tuple val("${task.process}"), val('python'), eval("python3 --version | sed 's/Python //'"), topic: versions, emit: versions_python

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    select_orthogroup.py \\
        ${recphyloxml} \\
        --gene ${meta.id} \\
        --output ${prefix}_orthogroup_ids.txt \\
        --log ${prefix}_orthogroup.log \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_orthogroup_ids.txt
    touch ${prefix}_orthogroup.log
    """
}
