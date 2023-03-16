/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowDrop.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.gtf ]
// for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
// if (params.gtf) { ch_input = file(params.gtf) } else { exit 1, 'Input GTF not specified!' }

// /*
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//     CONFIG FILES
// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// */

// ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
// ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
// ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
// ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { ABERRANT_EXPRESSION   } from '../subworkflows/nf-core/aberrantexpression'
include { ABERRANT_SPLICING     } from '../subworkflows/nf-core/aberrantsplicing'
include { MAE                   } from '../subworkflows/nf-core/mae'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

process MOVE_OUTPUT {
    input:
        each (moveVector)
        val (rootDir)

    shell:
        """
            #!/usr/bin/env python
            import os
            import shutil

            mVector = "!{moveVector}"
            mVector = mVector.replace("[", "[\\"").replace("]", "\\"]") \
                .replace(", ", "\\", \\"").replace("\\"]\\"", "\\"]").replace("\\"[\\"", "[\\"")
            mVector = eval(mVector)
            dstDir = "%sOutput_NF/%s/%s/%s" % ("!{rootDir}", mVector[0], mVector[1], mVector[2])

            for fName in mVector[3]:
                if os.path.isdir(fName):
                    shutil.rmtree(dstDir)
                    shutil.copytree(fName, dstDir)
                else:
                    shutil.copy(fName, dstDir)
        """
}

workflow DROP {
    ch_versions = Channel.empty()

    /* Convert TSV data to a list of dictionaries of format
     * {HEADER[j]: DATA[i][j]}, with j the index of column and
     * i the index of current row.
     */
    params.procAnnotation = Channel.fromPath(params.annotation)
        .splitCsv (sep: "\t", header: true)
        .map {
            val -> {
                // Resolve the relative to absolute paths.
                if (val.RNA_BAM_FILE != "") {
                    val.RNA_BAM_FILE = params.rootDataFolder + val.RNA_BAM_FILE
                }
                if (val.DNA_VCF_FILE != "") {
                    val.DNA_VCF_FILE = params.rootDataFolder + val.DNA_VCF_FILE
                }
                if  (val.GENE_COUNTS_FILE != "") {
                    val.GENE_COUNTS_FILE = params.rootDataFolder + val.GENE_COUNTS_FILE
                }
                if  (val.SPLICE_COUNTS_DIR != "") {
                    val.SPLICE_COUNTS_DIR = params.rootDataFolder + val.SPLICE_COUNTS_DIR
                }
                val
            }
        }

    if (params.aberrantexpression.active) {
        ABERRANT_EXPRESSION(params)
        MOVE_OUTPUT(ABERRANT_EXPRESSION.out.resultsAll, params.rootDataFolder)
    }

    if (params.aberrantsplicing.active) {
        ABERRANT_SPLICING(params)
        MOVE_OUTPUT(ABERRANT_SPLICING.out.resultsAll, params.rootDataFolder)
    }

    if (params.mae.active) {
        MAE(params)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// workflow.onComplete {
//     if (params.email || params.email_on_fail) {
//         NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
//     }
//     NfcoreTemplate.summary(workflow, params, log)
//     if (params.hook_url) {
//         NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
//     }
// }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
