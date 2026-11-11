process ETE_FILTER {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ete3:3.1.2' :
        'quay.io/biocontainers/ete3:3.1.2' }"

    input:
    tuple val(meta), path(fasta)
    tuple val(meta2), path(taxidmap)
    path(etedotdir)

    output:
    tuple val(meta), path("*_filtered.fasta")                                                             , emit: fasta
    tuple val(meta2), path("*_speciescodes.txt")                                                          , emit: txt
    tuple val("${task.process}"), val('ete3'), eval('python -c "import ete3; print(ete3.__version__)"'), topic: versions, emit: versions_ete3

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # ete3 looks for its taxonomy database in \$HOME/.etetoolkit
    export HOME=\$PWD
    rename_seqs.py --taxidmap "${taxidmap}" --input "${fasta}" --prefix "${prefix}"
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_filtered.fasta
    touch ${prefix}_speciescodes.txt
    """
}
