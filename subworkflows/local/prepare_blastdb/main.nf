include { BLAST_UPDATEBLASTDB } from '../../../modules/nf-core/blast/updateblastdb/main'
include { BLAST_MAKEBLASTDB   } from '../../../modules/nf-core/blast/makeblastdb/main'

workflow PREPARE_BLASTDB {

    take:
    val_blastdb_option   // string: 'update', 'build' or 'current'
    val_blastdb_update   // string: name of an NCBI pre-formatted database (update)
    val_blastdb_build    // string: path to the FASTA for a custom database (build)
    val_blastdb_buildmap // string: path to the sequence id -> taxid map (build)
    val_blastdb_dir      // string: path to an existing database (current)

    main:
    ch_blastdb = channel.empty()

    // 1. download from ncbi databases (update)
    if (val_blastdb_option == 'update') {
        ch_blastdb_in = channel.of( tuple( [ id: "BLASTDB" ], val_blastdb_update ))
        BLAST_UPDATEBLASTDB( ch_blastdb_in )
        ch_blastdb = BLAST_UPDATEBLASTDB.out.db
    }
    // 2. build custom databases from sequences (build)
    else if (val_blastdb_option == 'build') {
        ch_blastdb_in = channel
            .fromPath(val_blastdb_build, checkIfExists: true)
            .map { dbpath -> tuple( [ id: "BLASTDB" ], file(dbpath) ) }
        ch_taxmap = channel.value(file(val_blastdb_buildmap, checkIfExists: true))
        BLAST_MAKEBLASTDB( ch_blastdb_in, ch_taxmap )
        ch_blastdb = BLAST_MAKEBLASTDB.out.db
    }
    // 3. use existing database (current)
    else if (val_blastdb_option == 'current') {
        ch_blastdb = channel.of( tuple( [ id: "BLASTDB" ], file(val_blastdb_dir) ))
    }

    emit:
    db = ch_blastdb // channel: [ val(meta), path(db) ]
}
