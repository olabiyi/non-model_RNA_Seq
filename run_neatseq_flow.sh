#!/usr/bin/env bash

# AUTHOR : Olabiyi Obayomi (obadbotanist@yahoo.com)
# VERSION : 1.0

set -e

USAGE="$(basename "$0") [-h -T value] 
-- $(basename "$0"): Runs the non-model organisms RNA Seq pipeline on the NeatSeq_Flow platform

--EXAMPLE: "$(basename "$0")" -T 00.Quality_check 
           "$(basename "$0")"
where:
    -h  Show this help text.
    -p  Neatseq_flow parameter file that has been modified by the script 'prepare_parameter_file.sh'.
    -s  Neatseq_flow sample file.
    -m  Samples to treatment mapping file.
    -T  Tag or section name within the parameter file to run. Can be 'all' or any tag name in the parameter file. Default: 'all', run the whole pipeline.
"

# Print usage and exit if no arguement is passed to the script
if [ $# -eq 0 ]; then  echo; echo "$USAGE"; exit 1; fi


### Terminal Arguments ---------------------------------------------------------

# Import user arguments
while getopts ':hp:s:m:T:' OPTION; do
  case $OPTION in
    h) echo "$USAGE"; exit 1;;
    p) PARAMETER_FILE=$OPTARG;;
    s) SAMPLE_FILE=$OPTARG;;
    m) SAMPLE_MAPPING_FILE=$OPTARG;;
    T) TAG=$OPTARG;;
    :) printf "missing argument for -$OPTARG\n" >&2; exit 1;;
    \?) printf "invalid option for -$OPTARG\n" >&2; exit 1;;
  esac
done

if [ -z ${PARAMETER_FILE+x} ]; then
    echo "-p $MISSING"
    echo; echo "Please supply the parameter file that has been edited by the script 'prepare_parameter_file.sh'."
    echo "Exiting...."
    exit 1"
fi
echo; echo "Your Parameter file is ${PARAMETER_FILE}."

if [ -z ${SAMPLE_FILE+x} ]; then echo "-s $MISSING"; echo;echo "$USAGE"; exit 1; fi;
echo; echo "Your Sample file is  ${SAMPLE_FILE}."

if [ -z ${SAMPLE_MAPPING_FILE+x} ]; then 
    echo "-m $MISSING"
    echo "You must supply a mapping or grouping file"
    echo "$USAGE"
    exit 1
fi
echo; echo "Your mapping file is  ${SAMPLE_MAPPING_FILE}."

 
if [ -z ${TAG+x} ]; then TAG="all"; fi; 
echo; echo "I will run  ${TAG} section(s) of ${PARAMETER_FILE}."


# Activate Netaseq_flow and run
source activate NeatSeq_Flow
export CONDA_BASE=$(conda info --root)

if [ -d logs/ ]; then
  
    runID=$(ls logs/log*txt | sed -E 's/log(s\/)?_?|\.txt//g') && runID=($runID)
    # Get the most recent runID
    runID=${runID[-1]}
  
    neatseq_flow.py -s $SAMPLE_FILE -p $PARAMETER_FILE -g $SAMPLE_MAPPING_FILE -r ${runID}

else

    neatseq_flow.py -s $SAMPLE_FILE -p $PARAMETER_FILE -g $SAMPLE_MAPPING_FILE

fi

if [ "${TAG}" == "all" ]; then
    bash scripts/00.workflow.commands.sh  1> null &
else
    bash scripts/tags_scripts/${TAG}.sh 1> null & || echo "The tag - $TAG you provided does not exist, please provide a valid tag and run again"; exit 1;
fi
