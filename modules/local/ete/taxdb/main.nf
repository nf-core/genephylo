process ETE_TAXDB {
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ete3:3.1.2' :
        'quay.io/biocontainers/ete3:3.1.2' }"

    input:
    path(taxdump)

    output:
    path(".etetoolkit")                                                                                   , emit: etedotdir
    tuple val("${task.process}"), val('ete3'), eval('python -c "import ete3; print(ete3.__version__)"'), topic: versions, emit: versions_ete3

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # ete3 writes its taxonomy database to \$HOME/.etetoolkit
    export HOME=\$PWD
    python -c "from ete3 import NCBITaxa ; ncbi = NCBITaxa()"
    """

    stub:
    """
    mkdir -p .etetoolkit
    touch .etetoolkit/taxa.sqlite
    """
}
