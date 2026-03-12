process ETE_TAXDB {
    label 'process_low'

    conda "conda-forge::ete3==3.1.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ete3:3.1.2' :
        'quay.io/biocontainers/ete3:3.1.2' }"

    input:
    path(taxdump)

    output:
    path(".etetoolkit") , emit: etedotdir
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Set up writable environment for ete3
    export HOME=\$PWD
    python -c "from ete3 import NCBITaxa ; ncbi = NCBITaxa()"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ete3: \$(python -c "import ete3; print(ete3.__version__)")
    END_VERSIONS
    """
}
