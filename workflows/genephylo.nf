/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// BLAST DATABASE
include { BLAST_UPDATEBLASTDB } from '../modules/nf-core/blast/updateblastdb/main'
include { BLAST_MAKEBLASTDB } from '../modules/nf-core/blast/makeblastdb/main'

// INITIAL SEQUENCE RETRIEVAL
include { BLAST_BLASTN } from '../modules/nf-core/blast/blastn/main'
include { BLAST_TBLASTN } from '../modules/nf-core/blast/tblastn/main'
include { FILTER_BLASTEXTRACT } from '../modules/local/filter/blastextract/main'
include { BLAST_BLASTDBCMD } from '../modules/nf-core/blast/blastdbcmd/main'
include { SEQKIT_RMDUP } from '../modules/nf-core/seqkit/rmdup/main'
include { ETE_TAXDB } from '../modules/local/ete_taxdb'
include { ETE_FILTER } from '../modules/local/ete_filter'

// INITIAL ALIGNMENT AND TREE
include { TD2_LONGORFS } from '../modules/nf-core/td2/longorfs/main'
include { MAFFT_ALIGN as MAFFT_INITIAL } from '../modules/nf-core/mafft/align/main'
include { FILTER_CLEANORFS } from '../modules/local/filter/cleanorfs/main'
include { FASTTREE } from '../modules/nf-core/fasttree/main'

// DUPLICATION AND ISOFORMS (TO ADD)
include { TREERECS } from '../modules/nf-core/treerecs/main'
include { FILTER_ORTHOGROUP } from '../modules/local/filter/orthogroup/main'
include { SEQKIT_GREP } from '../modules/nf-core/seqkit/grep/main'

// FINAL ALIGNMENT AND TREE
include { MAFFT_ALIGN as MAFFT_FINAL } from '../modules/nf-core/mafft/align/main'
include { MACSE_REFINEALIGNMENT } from '../modules/nf-core/macse/refinealignment/main'
include { IQTREE } from '../modules/nf-core/iqtree/main'

// PIPELINE
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_genephylo_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow GENEPHYLO {

	take:
	ch_samplesheet // channel: samplesheet read in from --input

	main:

	ch_versions = channel.empty()

	//
	// SUBWORKFLOW: build BLAST database for subsequent analyses (3 options)
	//

	ch_blastdb_in = channel.empty()
	ch_blastdb = channel.empty()

	// 1. download from ncbi databases (update)
	if (params.blastdb_option == 'update') {

		ch_blastdb_in = channel.of( tuple( [ id: "BLASTDB" ], params.blastdb_update ))

		BLAST_UPDATEBLASTDB( ch_blastdb_in )
		ch_blastdb = BLAST_UPDATEBLASTDB.out.db

	}
	// 2. build custom databases from sequences (build)
	else if (params.blastdb_option == 'build') {

		channel
			.fromPath(params.blastdb_build, checkIfExists: true)
			.map { dbpath -> tuple( [ id: "BLASTDB" ], file(dbpath) ) }
			.set { ch_blastdb_in }

	        ch_taxmap = channel.value(file(params.blastdb_buildmap, checkIfExists: true))
		BLAST_MAKEBLASTDB( ch_blastdb_in, ch_taxmap )
		ch_blastdb = BLAST_MAKEBLASTDB.out.db

	}
	// 3. use existing database (current)
	else if (params.blastdb_option == 'current') {

		ch_blastdb = channel.of(tuple([ id: "BLASTDB" ], file(params.blastdb_dir) ))

	}

	//
	// SUBWORKFLOW: run BLAST on target sequences (2 options)
	//

	ch_blast_in = ch_samplesheet.map { meta, fasta, _tree -> tuple(meta, file(fasta)) }
	ch_blastdb_in = ch_blastdb.first()
	ch_blast_out = channel.empty()

	// 1. nt sequence: blastn
	if ( params.blast_type == 'nt' ) {

		BLAST_BLASTN( ch_blast_in, ch_blastdb_in, [], params.blast_taxids, [] )
		ch_blast_out = BLAST_BLASTN.out.txt

	}
	// 2. aa sequence: tblastn
	else if ( params.blast_type == 'aa' ) {

		BLAST_TBLASTN( ch_blast_in, ch_blastdb_in )
		ch_blast_out = BLAST_TBLASTN.out.txt

	}

	// get the first column of the blast results file
	FILTER_BLASTEXTRACT( ch_blast_out )
	ch_accessions_out = FILTER_BLASTEXTRACT.out.accessions

	ch_extract_in = ch_accessions_out.map { meta, batch_file ->
		tuple(meta, null, batch_file)
	}

	BLAST_BLASTDBCMD(ch_extract_in, ch_blastdb_in)
	ch_extract_out = BLAST_BLASTDBCMD.out.fasta

	SEQKIT_RMDUP(ch_extract_out)
	ch_rmdup = SEQKIT_RMDUP.out.fastx

	ch_taxdump = params.taxdump ? channel.value(file(params.taxdump, checkIfExists: true)) : []
	ETE_TAXDB(ch_taxdump)
	ETE_FILTER(ch_rmdup, ch_blast_out, ETE_TAXDB.out.etedotdir)

	ch_orf_in = ETE_FILTER.out.fasta

	TD2_LONGORFS(ch_orf_in, [ [:], [], [] ], [ [:], [] ])

	// keep only the CDS file (longest_orfs.cds) from the TD2.LongOrfs outputs
	ch_orf_cds = TD2_LONGORFS.out.orfs
		.map { meta, files -> tuple(meta, files.find { file -> file.name.endsWith('.cds') }) }

	// keep the longest ORF for each sequence and clean the sequence ids
	FILTER_CLEANORFS ( ch_orf_cds )
	ch_aln_in = FILTER_CLEANORFS.out.fasta

	//
	// SUBWORKFLOW: phylo
	//

	// build initial alignment
	MAFFT_INITIAL (
		ch_aln_in, [ [:], [] ], [ [:], [] ], [ [:], [] ], [ [:], [] ], [ [:], [] ], false
		)

	ch_mafft_out = MAFFT_INITIAL.out.fas

	// build initial phylogenetic tree
	FASTTREE ( ch_mafft_out )

	ch_fasttree_out = FASTTREE.out.phylogeny
	ch_treerecs_in = ch_fasttree_out.map { meta, tree ->
		tuple(meta, tree, params.species_tree)
	}

	// tree reconciliation to identify orthogroups

	TREERECS ( ch_treerecs_in )

	ch_treerecs_out = TREERECS.out.rectree

	// extract the orthogroup for the gene of interest

	FILTER_ORTHOGROUP ( ch_treerecs_out )

	ch_grep_in = ch_aln_in
		.join(FILTER_ORTHOGROUP.out.ids)
		.multiMap { meta, fasta, ids ->
			sequence: tuple(meta, fasta)
			pattern:  ids
		}

	SEQKIT_GREP ( ch_grep_in.sequence, ch_grep_in.pattern, 'fa' )

	ch_orthogroup_out = SEQKIT_GREP.out.filter

	MAFFT_FINAL (
		ch_orthogroup_out, [ [:], [] ], [ [:], [] ], [ [:], [] ], [ [:], [] ], [ [:], [] ], false
		)
	
	ch_macse_in = MAFFT_FINAL.out.fas

	MACSE_REFINEALIGNMENT ( ch_macse_in )

	ch_macse_out = MACSE_REFINEALIGNMENT.out.nt

	ch_iqtree_in = ch_macse_out
		.map { meta, alignment -> tuple(meta, alignment, []) }

	IQTREE (
	 	ch_iqtree_in, [], [], [], [], [], [], [], [], [], [], [], []
	 	)

	// if ( params.tree_tool == "iqtree" ) {

	// }
	// else if ( params.tree_tool == "fasttree" ) {
	// 	ch_fasttree_in = ch_mafft_out.map { meta, alignment -> alignment }
	// }

    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'genephylo_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

	emit:
	versions       = ch_versions.toList()                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
