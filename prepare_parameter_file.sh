#!/usr/bin/env bash

# AUTHOR : Olabiyi Obayomi (obadbotanist@yahoo.com)
# VERSION : 1.0

set -e

USAGE="$(basename "$0") [-h] [-p file] [ -p file -S comma separated list -r value -C comma separated list
                        -m file -t value -g value -c value -b value -n comma separated list -q value -R value -M value ] 
-- $(basename "$0"): prepares your parameter file for NeatSeq_Flow.

--EXAMPLE: "$(basename "$0")"  -p non_model_RNA_Seq.yaml -m sample_grouping.txt 
                              -t CUTICULA  -b metazoa_odb9.tar.gz  -q bioinfo.q 
			      -g Treatment -c Treatment,level1,level2|Treatment,level1,level3|Treatment,level2,level3
			      -n sge1027,sge1029,sge1030,sge1031,sge1032,sge1033,sge213,sge214,sge224,sge37,sge22 -R 2 -M 3
                              -C Import_reads,99.reanalyze,QC_imported_reads,99.reanalyze
where:
    -h  Show this help text.
    -v  Show this script's version number.
    -p  Neatseq_flow parameter file to modify and run. It must be correctly formated as the default file.
          Default: downloaded from the internet.
    -S  A comma separated list without spaces of step names in the parameter file to skip.
          Example Map_reads_to_rRNA,Assemble_Transcriptome,Generate_Gene_Transcript_Map
    -r  Should your genes be BLASTed against NCBI's Refseq protein database? Set it to any value and it will be BLASTed.
        By default your genes won't be blasted against Refseq because it takes a long time to complete.
    -m  Samples to treatment mapping file.
    -t  Prefix to use when renaming transcripts. Default: ''.
    -g  Group or treatment name on the mapping file to use during filtering and statistical analysis.
    -c  Comparison of group 'g' to use during DeSeq2 analysis. Multiple comparisons should be separted by '|'.
	  Example Treatment,level1,level2|Treatment,level1,level3. Default: run all possible comparisons.
    -b  Basename of tar file name of your choice BUSCO dataset. Example metazoa_odb9.tar.gz.
    -n  A comma separated list without spaces of qsub nodes to run your jobs on. Example sge1027,sge1029,sge1030,sge1031
    -q  A qsub queue. Example bioinfo.q
    -M  Minimum count for filtering out lowly expressed transcripts. Default value is 3.
    -R  Minimum number of samples or replicates within a treatment group to use during filtering. Default value is 2.
    -C  Change tag name. Comma separated list of pairs of step name folowed by new tag name. For example: Import_reads,99.reanalyze,QC_imported_reads,99.reanalyze.
"

# Print usage if no arguement is passed to the script
if [ $# -eq 0 ]; then  echo; echo "$USAGE"; exit 1; fi
VERSION=1.0

### Terminal Arguments ---------------------------------------------------------

# Import user arguments
while getopts ':hvp:s:S:r:m:t:g:c:b:n:q:M:R:C:' OPTION; do
  case $OPTION in
    h) echo; echo "$USAGE"; exit 1;;
    v) echo;echo "v${VERSION}"; exit 1;;
    p) PARAMETER_FILE=$OPTARG;;
    S) SKIP_STEPS=$OPTARG;;
    r) REFSEQ=$OPTARG;;
    m) SAMPLE_MAPPING_FILE=$OPTARG;;
    t) TRANSCRIPT_PREFIX=$OPTARG;;
    g) TREATMENT_NAME=$OPTARG;;
    c) COMPARISON=$OPTARG;;
    b) BUSCO_DATABASE=$OPTARG;;
    n) QSUB_NODES=$OPTARG;;
    q) QSUB_Q=$OPTARG;;
    M) MINIMUM_COUNT=$OPTARG;;
    R) MINIMUM_REPLICATES=$OPTARG;;
    C) STEPS2CHANGE=$OPTARG;;
    :) printf "missing argument for -$OPTARG\n" >&2; exit 1;;
    \?) printf "invalid option for -$OPTARG\n" >&2; exit 1;;
  esac
done

# Activate the non_model_RNA_Seq conda environment
conda activate non_model_RNA_Seq || source activate non_model_RNA_Seq 
if [ $? -ne 0 ]; then 

    echo;echo "The non_model_RNA_Seq conda evironment has not been configured."
    echo;echo "Please run configure.sh before running this script $(basename "$0")"
    exit 1

fi

# Check missing arguments
MISSING="is missing but required. Exiting."

if [ -z ${PARAMETER_FILE+x} ]; then

    echo; echo "NeatSeq_Flow parmeter file not provided, am downloading a template..." 
    rm -rf non_model_RNA_Seq.yaml
    wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/non_model_RNA_Seq.yaml 
    PARAMETER_FILE="non_model_RNA_Seq.yaml"

fi
echo; echo "Your Parameter file is ${PARAMETER_FILE}."


# Set default import method to gzip -cd
sed -i -E "s/^(\s+import_seqs:\s+).+$/\1gzip -cd/g"  ${PARAMETER_FILE}


CHANGE_TAG=true
if [ -z ${STEPS2CHANGE} ]; then CHANGE_TAG=false; fi;

if [ $CHANGE_TAG == true ];then

    # Rename tag
    STEPS2CHANGE=$(echo ${STEPS2CHANGE[*]} |sed -E 's/,(\s+)?/ /g') && STEPS2CHANGE=($STEPS2CHANGE)

    NUMBER_OF_STEPS=$(( ${#STEPS2CHANGE[*]}/2 ))


    # Ensure that the steps to change are provided with a new tag name i.e contains step name and the new tag for that step
    if [ $(( ${#STEPS2CHANGE[*]}%2 )) -ne 0 ]; then

        echo "The step(s) and the new tag name(s) you provided : ${STEPS2CHANGE[*]}  are not complete. Exiting...."
        exit 1

    else
        declare i=0
        # Rename tag
        for count in $(seq 1 ${NUMBER_OF_STEPS});do

            declare STEP_NAME=${STEPS2CHANGE[$i]}
            declare NEW_TAG_NAME=${STEPS2CHANGE[$i+1]}
            declare inFile=$(grep -c "${STEP_NAME}" "${PARAMETER_FILE}")
           # echo "STEP name is : ${STEP_NAME} -> new tag name is: ${NEW_TAG_NAME}"
            if [ $inFile -eq 0 ]; then

                echo
                echo "${STEP_NAME} does not exist in ${PARAMETER_FILE}, hence i can't rename its tag."
                echo "Please provide only valid step names then try again. Exiting..."
                exit 1

            else
                 #echo "STEP name is : ${STEP_NAME} -> new tag name is: ${NEW_TAG_NAME}"
                 # Rename tag
                sed -i -E "s/^(\s+tag:\s+).+(\s#${STEP_NAME})/\1${NEW_TAG_NAME}\2/g" ${PARAMETER_FILE}

            fi

           let i+=2

        done

    fi

fi


# Ensure that no step has aleady been skipped in the parmeter file, if so, unskip them
# find the lines that this script had previously tagged for skipping in a previous run
declare inFile=$(grep -Ec "^\s+SKIP:\s+(#SKIP.+)" "${PARAMETER_FILE}")

#echo "am here"
# Unskip previously skipped steps
if [[ ${inFile} -gt 0 ]]; then

    sed -i -E "s/^(\s+)SKIP:\s+(#SKIP\s\S+)/\1\2:/g"  ${PARAMETER_FILE}
    echo; echo "Unskipped any previously skipped step in ${PARAMETER_FILE} before applying yours."

fi

# Check if ordinary SKIP tags have been used then exit with message 
BAD_LINES=$(grep -nE "^\s+SKIP(\s+)?:(\s+)?$" "${PARAMETER_FILE}" | cut -d " " -f1 | sed 's/://g')
BAD_LINES=($BAD_LINES)

if [ ${#BAD_LINES} -gt 0 ]; then 
echo "The folowing lines: ${BAD_LINES[*]} need to be corrected to work with this automated pipeline."
echo;echo "To Skip a step, the line should be formated this way:" 
echo "4 spaces followed by SKIP:4 spaces then #SKIP a spece then the step name:"
echo "For example to skip Make_filtered_transcripts_BLAST_db step, the line should be:"
echo "    SKIP:   #SKIP  Make_filtered_transcripts_BLAST_db"
echo
exit 1
fi 

declare -a REFSEQ_STEPS=(Refseq_protein_blastx Merge_refseq_blastx_xmls)

if [ -z ${REFSEQ+x} ]; then 

    for STEP in ${REFSEQ_STEPS[*]};do 

        sed -i -E "s/^(\s+)#SKIP ${STEP}(\s+)?:/\1SKIP:\1#SKIP ${STEP}/g" ${PARAMETER_FILE}

    done

    echo; echo "I will not blast your genes against Refseq protein database."

fi

if [ -z ${SAMPLE_MAPPING_FILE+x} ]; then echo "-m $MISSING"; echo "$USAGE"; exit 1; fi;
echo; echo "Your mapping file is  ${SAMPLE_MAPPING_FILE}."

if [ -z ${TRANSCRIPT_PREFIX+x} ]; then TRANSCRIPT_PREFIX=''; fi;
echo; echo "Your Transcript Prefix is ${TRANSCRIPT_PREFIX}."

if [ -z ${SKIP_STEPS+x} ]; then SKIP_STEPS="skip_nothing"; fi;

if [ -z ${MINIMUM_COUNT+x} ]; then MINIMUM_COUNT=3; fi; 
echo; echo "Your minimum count for filtering lowly expressed trancripts is  ${MINIMUM_COUNT}."

if [ -z ${MINIMUM_REPLICATES+x} ]; then MINIMUM_REPLICATES=2; fi; 
echo; echo "The transcript must exist in at least ${MINIMUM_REPLICATES} replicates with a minimum of ${MINIMUM_COUNT} count(s) for it to be retained."

if [ -z ${TREATMENT_NAME+x} ]; then echo "-g $MISSING"; echo "$USAGE"; exit 1; fi;
echo; echo "Your Treatment group is ${TREATMENT_NAME}."

if [ -z ${COMPARISON+x} ]; then 

     COMPARISON=$(Rscript $CONDA_PREFIX/bin/get_group_contrast.R ${SAMPLE_MAPPING_FILE} ${TREATMENT_NAME} |\
                 sed -e 's/\[1\] //g' | sed -e 's/"//g'); 

fi
echo; echo "These contrasts - ${COMPARISON} will be applied during DESeq2 analysis."

if [ -z ${BUSCO_DATABASE+x} ]; then echo "-b $MISSING, you must proved a BUSCO database."; echo "$USAGE"; exit 1; fi; 

if [ -z ${QSUB_NODES+x} ]; then 

    echo
    echo "-n $MISSING, you must provide a comma separated list of nodes to run your jobs on."
    echo "$USAGE"
    echo
    exit 1

fi 

if [ -z ${QSUB_Q+x} ]; then echo "-q $MISSING, you must provide a qsub queue."; echo;echo "$USAGE"; exit 1; fi; 


# Skip steps

if [ ${SKIP_STEPS} != "skip_nothing" ];then
    
    # Convert SKIP_STEPS into an array separated by spaces 
    SKIP_STEPS=$(echo ${SKIP_STEPS}| sed -E 's/,(\s+)?/ /g') && SKIP_STEPS=($SKIP_STEPS)

    for STEP in ${SKIP_STEPS[*]};do
        
       # Peform the substition i.e skip a step if it exists
        declare inFile=$(grep -c "${STEP}" "${PARAMETER_FILE}")
         
        if [ $inFile -eq 0 ]; then

                echo
                echo "${STEP} does not exist in ${PARAMETER_FILE}, hence I can't skip it."
                echo "Please provide only valid step names then retry. Exiting..."
                echo
                exit 1

        else

              if [ "${STEP}" == "Import_reads" ]; then

                 sed -i -E "s/^(\s+import_seqs:\s+)gzip\s-cd/\1..import../g"  ${PARAMETER_FILE}

              else

                  sed -i -E "s/^(\s+)#SKIP ${STEP}(\s+)?:/\1SKIP:    #SKIP ${STEP}/g"  ${PARAMETER_FILE}

              fi

 
        fi

    done

fi


DESEQ2=$(echo $CONDA_PREFIX| sed -e "s:envs/non_model_RNA_Seq::g") || exit 1;
BUSCO_DATABASE=$(basename $BUSCO_DATABASE| sed -e "s/\.tar\.gz//g") || exit 1;
RNA_DATABASE=$(ls $CONDA_PREFIX/databases/rRNA/*bwt | sed -E 's/\.bwt$//g') || \
echo;echo "rRNA database does not exist. Please run configure.sh to install it. exiting..."; exit 1;

declare -a TO_REPLACE=(RNA_DATABASE SAMPLE_MAPPING_FILE TRANSCRIPT_PREFIX TREATMENT_NAME 
                      COMPARISON CONDA_PATH DESEQ2 BUSCO_DATABASE QSUB_Q QSUB_NODES 
                      MINIMUM_COUNT MINIMUM_REPLICATES)
declare -a REPLACEMENTS=($RNA_DATABASE $SAMPLE_MAPPING_FILE $TRANSCRIPT_PREFIX $TREATMENT_NAME 
                         $COMPARISON $CONDA_PREFIX $DESEQ2 $BUSCO_DATABASE $QSUB_Q $QSUB_NODES 
                         $MINIMUM_COUNT $MINIMUM_REPLICATES)


# Set names
for i in ${!TO_REPLACE[*]}; do
 
    declare inFile=$(grep -c "${TO_REPLACE[$i]}" "${PARAMETER_FILE}")	
	
    if [ $inFile -eq 0 ]; then
     
        continue
    
    else
		
        sed -i -E "s:${TO_REPLACE[$i]}:${REPLACEMENTS[$i]}:g" ${PARAMETER_FILE}
   
    fi

done

conda deactivate || source deactivate
echo; echo "Your parameter file ${PARAMETER_FILE} is ready to run on Neatseq flow."
echo 
