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
    -T  Tag or section name within the parameter file to run. Can be 'all' or any tag name in the parameter file. Default: 'all', run the whole pipeline.
"

### Terminal Arguments ---------------------------------------------------------

# Import user arguments
while getopts ':hp:s:m:t:g:c:b:n:q:T:C:R:' OPTION; do
  case $OPTION in
    h) echo "$USAGE"; exit 1;;
    T) TAG=$OPTARG;;
    :) printf "missing argument for -$OPTARG\n" >&2; exit 1;;
    \?) printf "invalid option for -$OPTARG\n" >&2; exit 1;;
  esac
done
 
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
