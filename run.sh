#!/usr/bin/env bash
# AUTHOR : Olabiyi Obayomi (obadbotanist@yahoo.com)

set -e

USAGE="$(basename "$0") [-h] [-p file] [ -s file -m file -t value -g value -c value -b value -n comma separated list -q value -T value -R value -C value] 
-- $(basename "$0"): Runs the non-model organisms RNA Seq pipeline on the NeatSeq_Flow platform

--EXAMPLE: "$(basename "$0")" -s sample_file.nsfs -p non_model_RNA_Seq.yaml -m sample_grouping.txt 
                              -t CUTICULA  -b metazoa_odb9.tar.gz  -q bioinfo.q 
							  -g Treatment -c Treatment,level1,level2|Treatment,level1,level3|Treatment,level2,level3
							  -n sge1027,sge1029,sge1030,sge1031,sge1032,sge1033,sge213,sge214,sge224,sge37,sge22
							  -T 00.Quality_check -R 2 -C 3
where:
    -h  Show this help text.
    -p  Neatseq_flow parameter file to modify and run. It must be correctly formated as the default file. Default: downloads it from the internet.
    -s  Neatseq_flow sample file.
    -m  Samples to treatment mapping file.
    -t  Prefix to use when renaming transcripts. Default: ''.
    -g  Group or Treatment name on the mapping file to use for filtering and statistical analysis.
    -c  Contrast or comparison to use during DeSeq2 analysis. Multiple comparisons should be separted by '|'.
	     Example Treatment,level1,level2|Treatment,level1,level3. Default: run all possible comparisons.
	-b  Tar file name of your choice BUSCO dataset. Example metazoa_odb9.tar.gz.
	-n  A comma separted list of nodes without spaces to run your jobs on. example sge1027,sge1029,sge1030,sge1031
	-q  A qsub queue. Example bioinfo.q.
	-T  Tag or section name within the parameter file to run. Can be 'all' or any tag name in the parameter file. Default: all, run the whole pipeline.
	-C  Minimum count for filtering out lowly expresed transcripts. default is 3.
	-R  Minimum number of samples or replicates within a treatment group to use during filtering. default is 2.
"

### Terminal Arguments ---------------------------------------------------------

# Import user arguments
while getopts ':hp:s:m:t:g:c:b:n:q:T:C:R:' OPTION; do
  case $OPTION in
    h) echo "$USAGE"; exit 1;;
    p) PARAMETER_FILE=$OPTARG;;
    s) SAMPLE_FILE=$OPTARG;;
    m) SAMPLE_MAPPING_FILE=$OPTARG;;
    t) TRANSCRIPT_PREFIX=$OPTARG;;
    g) TREATMENT_NAME=$OPTARG;;
	c) COMPARISON=$OPTARG;;
	b) BUSCO_DATABASE=$OPTARG;;
	n) QSUB_NODES=$OPTARG;;
	q) QSUB_Q=$OPTARG;;
	T) TAG=$OPTARG;;
	C) MINIMUM_COUNT=$OPTARG;;
	R) MINIMUM_REPLICATES=$OPTARG;;
    :) printf "missing argument for -$OPTARG\n" >&2; exit 1;;
    \?) printf "invalid option for -$OPTARG\n" >&2; exit 1;;
  esac
done

# Activate the non_model_RNA_Seq conda environment
source activate non_model_RNA_Seq

# Check missing arguments
MISSING="is missing but required. Exiting."

if [ -z ${PARAMETER_FILE+x} ]; then
echo "NeatSeq_Flow parmeter file not provided, am downloading a template..." 
wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/non_model_RNA_Seq.yaml 
PARAMETER_FILE="non_model_RNA_Seq.yaml"
fi
echo "Your Parameter file is ${PARAMETER_FILE}"

if [ -z ${SAMPLE_FILE+x} ]; then echo "-s $MISSING"; echo "$USAGE"; exit 1; fi; 
echo "Your Sample file is  ${SAMPLE_FILE}"

if [ -z ${SAMPLE_MAPPING_FILE+x} ]; then echo "-m $MISSING"; echo "$USAGE"; exit 1; fi;
echo "Your mapping file is  ${SAMPLE_MAPPING_FILE}"

if [ -z ${TRANSCRIPT_PREFIX+x} ]; then TRANSCRIPT_PREFIX=''; fi;
echo "Your Transcript Prefix is ${TRANSCRIPT_PREFIX}"
 
if [ -z ${TAG+x} ]; then TAG="all"; fi; 
echo "I will run  ${TAG} section(s) of ${PARAMETER_FILE}"

if [ -z ${MINIMUM_COUNT+x} ]; then MINIMUM_COUNT=3; fi; 
echo "Your minimum count for filtering lowly expressed trancripts is  ${MINIMUM_COUNT}"

if [ -z ${MINIMUM_REPLICATES+x} ]; then MINIMUM_REPLICATES=2; fi; 
echo "The transcript must exist in at least ${MINIMUM_REPLICATES} replicates with a minimum of ${MINIMUM_COUNT} count(s) for it to be retained "

if [ -z ${TREATMENT_NAME+x} ]; then echo "-g $MISSING"; echo "$USAGE"; exit 1; fi;
echo "Your Treatment group is ${TREATMENT_NAME}"

if [ -z ${COMPARISON+x} ]; then COMPARISON=$(Rscript $CONDA_PREFIX/bin/get_group_contrast.R ${SAMPLE_MAPPING_FILE} ${TREATMENT_NAME} | sed -e 's/\[1\] //g' | sed -e 's/"//g'); fi;
echo "These contrasts - ${COMPARISON} will be applied during DESeq2 analysis"

if [ -z ${BUSCO_DATABASE+x} ]; then echo "-b $MISSING, you must proved a BUSCO database"; echo "$USAGE"; exit 1; fi; 

if [ -z ${QSUB_NODES+x} ]; then echo "-n $MISSING, you must provide a comma separted list of nodes to run your jobs on"; echo "$USAGE"; exit 1; fi; 

if [ -z ${QSUB_Q+x} ]; then echo "-q $MISSING, you must provide a qsub queue"; echo "$USAGE"; exit 1; fi; 


BUSCO_DATABASE=$(echo $BUSCO_DATABASE| sed -e "s/\.tar\.gz//g")
echo "BUSCO_DATABASE - ${BUSCO_DATABASE}"

DESEQ2=$(echo $CONDA_PREFIX| sed -e "s:envs/non_model_RNA_Seq::g")
BUSCO_DATABASE=$(echo $BUSCO_DATABASE| sed -e "s/\.tar\.gz//g")
RNA_DATABASE=$(ls $CONDA_PREFIX/databases/rRNA/)

declare -a TO_REPLACE=(RNA_DATABASE SAMPLE_MAPPING_FILE TRANSCRIPT_PREFIX TREATMANT_NAME COMPARISON CONDA_PATH DESEQ2 BUSCO_DATABASE QSUB_Q QSUB_NODES MINIMUM_COUNT MINIMUM_REPLICATES)
declare -a REPLACEMENTS=($RNA_DATABASE $SAMPLE_MAPPING_FILE $TRANSCRIPT_PREFIX $TREATMENT_NAME $COMPARISON $CONDA_PREFIX $DESEQ2 $BUSCO_DATABASE $QSUB_Q $QSUB_NODES $MINIMUM_COUNT $MINIMUM_REPLICATES)

# Get length of an array
arraylength=${#REPLACEMENTS[@]}
# Set names
for (( i=1; i<${arraylength}+1; i++ )); do 
sed -i -E "s:${TO_REPLACE[$i-1]}:${REPLACEMENTS[$i-1]}:g" ${PARAMETER_FILE}
done

source deactivate 

# Activate Netaseq_flow and run
source activate NeatSeq_Flow
export CONDA_BASE=$(conda info --root)
neatseq_flow.py -s $SAMPLE_FILE -p $PARAMETER_FILE -g $SAMPLE_MAPPING_FILE
if [ "${TAG}" == "all" ]; then
bash scripts/00.workflow.commands.sh  1> null &
else
bash scripts/tags_scripts/${TAG}.sh || echo "The tag - $TAG you provided does not exist, please provide a valid tag and run again"; exit 1;
fi
