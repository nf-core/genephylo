process GAWK_CLEANORFS {
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
    // For each input sequence, keep only the longest ORF reported by TD2.LongOrfs
    // (ties: the first one encountered) and clean its id: drop the header description
    // and the ORF suffix. Sequences are written in their order of first appearance.
    """
    gawk '
        function keep() {
            if (id == "") return
            if (!(id in best_len)) { order[++n] = id; best_len[id] = -1 }
            if (length(seq) > best_len[id]) { best_len[id] = length(seq); best_seq[id] = seq }
        }
        /^>/ {
            keep()
            id = substr(\$1, 2)
            sub(/${suffix}\$/, "", id)
            seq = ""
            next
        }
        { gsub(/[[:space:]]/, ""); seq = seq \$0 }
        END {
            keep()
            for (i = 1; i <= n; i++) {
                print ">" order[i]
                print best_seq[order[i]]
            }
        }
    ' ${fasta} > ${prefix}.fasta
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}_clean"
    """
    touch ${prefix}.fasta
    """
}
