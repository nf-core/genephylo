process ETE_TAXDB {
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ete3:3.1.2' :
        'quay.io/biocontainers/ete3:3.1.2' }"

    input:
    path(taxdump)

    output:
    path(".etetoolkit") , emit: etedotdir
    tuple val("${task.process}"), val('ete3'), eval('python -c "import ete3; print(ete3.__version__)"'), topic: versions, emit: versions_ete3

    when:
    task.ext.when == null || task.ext.when

    script:
    def taxdump_arg = taxdump ? "taxdump_file='${taxdump}'" : ''
    """
    # ete3 writes its taxonomy database to \$HOME/.etetoolkit
    # with --taxdump, build it from the given file, otherwise download it from NCBI
    export HOME=\$PWD
    python -c "from ete3 import NCBITaxa ; ncbi = NCBITaxa(${taxdump_arg})" || {
        echo "ERROR: could not download or build the NCBI taxonomy database. See the Python error above for the cause." >&2
        echo "If the download failed, you can provide the file yourself: download https://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz and rerun with --taxdump /path/to/taxdump.tar.gz" >&2
        exit 1
    }
    """

    stub:
    """
    mkdir -p .etetoolkit
    touch .etetoolkit/taxa.sqlite
    """
}
