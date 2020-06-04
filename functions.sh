# Print step in non_model_RNA_Seq.yaml
# GET thelocation of the step
function print_step(){
    
	# STEP - name of step with the PARAMETER_FILE to be printed
	# PARAMETER_FILE - approriately formated parameter file.
	
    # USAGE print_step <STEP_NAME> <PARAMETER_FILE>
    # EXAMPLE: print_step Import_reads: non_model_RNA_Seq.yaml
    local STEP=$1
    local PARAMETER_FILE=$2

    local COORDINATES=$(grep -n "${STEP}" "${PARAMETER_FILE}" | cut -d " " -f1 |\
    sed -e 's/://g') && COORDINATES=($COORDINATES)
    # print the step 
    sed -n "${COORDINATES[0]},${COORDINATES[1]}p" "${PARAMETER_FILE}"

}


function insert_step() {
        
		# STEP -  a multiline string containing the parameters to a step to be inserted
		# AFTER_STEP - is the name of the step the new step "STEP" should be inserted
		# PARAMETER_FILE - approriately formated parameter file.
		
		# USAGE insert_step <MULTILINE_STEP_STRING> <INSERT_AFTER_STEP> <PARAMETER_FILE>
		# EXAMPLE: insert_step ${MULTILINE_STEP_STRING} Import_reads non_model_RNA_Seq.yaml
        local STEP=$1
		local AFTER_STEP=$2
		local PARAMETER_FILE=$3
		
		local AFTER_LINE=grep -En "^\s+#SKIP\s${AFTER_STEP}"  "${PARAMETER_FILE}"
		
		(sed -n "1,${AFTER_LINE}p" "${PARAMETER_FILE}"; echo ${STEP}; \
		sed -n "$(( AFTER_LINE+1 )),$p" "${PARAMETER_FILE}")

}



function rename_tag(){

    # USAGE rename_tag <STEPS2CHANGE> <PARAMETER_FILE>
	# STEPS2CHANGE - comma separated list of pairs of steps2change,new_step_name.
	# PARAMETER_FILE - approriately formated parameter file.
    # rename_tag "Import_reads,99.reanalyze,QC_imported_reads,99.reanalyze" non_model_RNA_Seq.yaml
    local STEPS2CHANGE=$1
	local PARAMETER_FILE=$2
	
    # Rename tag
    STEPS2CHANGE=$(echo ${STEPS2CHANGE[*]} |sed -E 's/,(\s+)?/ /g') && STEPS2CHANGE=($STEPS2CHANGE)

    NUMBER_OF_STEPS=$(( ${#STEPS2CHANGE[*]}/2 ))


    # Ensure that the steps to change are provided with a new tag name i.e contains pairs of step name and the new tag names
    if [ $(( ${#STEPS2CHANGE[*]}%2 )) -ne 0 ]; then

        echo "The pair(s) of step(s) and new tag name(s) you provided : ${STEPS2CHANGE[*]}  is/are  incomplete."
        echo "Please provide complete pairs then try again.  Exiting...."
        exit 1

    else
        declare i=0
        # Rename tag
        for count in $(seq 1 ${NUMBER_OF_STEPS});do

            declare STEP_NAME=${STEPS2CHANGE[$i]}
            declare NEW_TAG_NAME=${STEPS2CHANGE[$i+1]}
            declare inFile=$(grep -c "${STEP_NAME}" "${PARAMETER_FILE}")

            if [ $inFile -eq 0 ]; then

                echo
                echo "${STEP_NAME} does not exist in ${PARAMETER_FILE}, hence i can't rename its tag."
                echo "Please provide only valid step names then try again. Exiting..."
                exit 1

            else
                 #echo "STEP name is : ${STEP_NAME} -> new tag name is: ${NEW_TAG_NAME}"

                sed -i -E "s/^(\s+tag:\s+).+(\s#${STEP_NAME})/\1${NEW_TAG_NAME}\2/g" ${PARAMETER_FILE}

            fi
            let i+=2

        done

    fi
 
	
}


function unskip_step(){

	local PARAMETER_FILE=$2

    # Ensure that no step has aleady been skipped in the parmeter file, if so, unskip them
    # find the lines that this script had previously tagged for skipping in a previous run

    declare inFile=$(grep -Ec "^\s+SKIP:\s+(#SKIP.+)" "${PARAMETER_FILE}")

    # Unskip previously skipped steps
    if [[ ${inFile} -gt 0 ]]; then

        sed -i -E "s/^(\s+)SKIP:\s+(#SKIP\s\S+)/\1\2:/g"  ${PARAMETER_FILE}
        echo; echo "Unskipped any previously skipped step in ${PARAMETER_FILE} before applying yours."

    fi

}



function skip_steps(){

    local SKIP_STEPS=$1
	local PARAMETER_FILE=$2
	
    # Convert SKIP_STEPS into an array separated by spaces
    SKIP_STEPS=$(echo ${SKIP_STEPS}| sed -E 's/,(\s+)?/ /g') && SKIP_STEPS=($SKIP_STEPS)

    for STEP in ${SKIP_STEPS[*]};do

       # Peform the substition i.e skip a step if it exists
        declare inFile=$(grep -c "${STEP}" "${PARAMETER_FILE}")

        if [ $inFile -eq 0 ]; then

                echo
                echo "${STEP} does not exist in ${PARAMETER_FILE}, hence i can't skip it."
                echo "Please provide only valid step names then retry. Exiting..."
                exit 1

        else

              if [ "${STEP}" == "Import_reads" ]; then

                 sed -i -E "s/^(\s+import_seqs:\s+)gzip\s-cd/\1..import../g"  ${PARAMETER_FILE}

              else

                  sed -i -E "s/^(\s+)#SKIP ${STEP}(\s+)?:/\1SKIP:    #SKIP ${STEP}/g"  ${PARAMETER_FILE}

              fi
        fi

    done


}


function run_neatseq_flow(){

    # USAGE run_neatseq_flow <SAMPLE_FILE> <PARAMETER_FILE> <SAMPLE_MAPPING_FILE> [TAG_NAME]
	# SAMPLE_FILE - Neatseq_flow sample file..
	# PARAMETER_FILE - approriately formated Neatseq_flow parameter file.
	# SAMPLE_MAPPING_FILE - Samples to treatment mapping file.
    # run_neatseq_flow sample_data.nsfs non_model_RNA_Seq.yaml sample_grouping.txt

    	local SAMPLE_FILE=$1
	local PARAMETER_FILE=$2
	local SAMPLE_MAPPING_FILE=$3
	local TAG=${4:-all} # set defualt tag to all

    # Activate Netaseq_flow and run
    conda activate NeatSeq_Flow || source activate NeatSeq_Flow
    if [ $? -ne 0 ]; then

        echo "You have not installed NeatSeq_Flow."
        echo "Please run configure.sh before running this script $(basename "$0")"
        exit 1

    fi

    export CONDA_BASE=$(conda info --root)

    if [ -d logs/ ]; then

        runID=$(ls logs/log*txt | sed -E 's/log(s\/)?_?|\.txt//g') && runID=($runID)
        # Get the most recent runID
        runID=${runID[-1]}

        neatseq_flow.py -s $SAMPLE_FILE -p $PARAMETER_FILE -g $SAMPLE_MAPPING_FILE -r ${runID}

    else

        neatseq_flow.py -s $SAMPLE_FILE -p $PARAMETER_FILE -g $SAMPLE_MAPPING_FILE

    fi

    # Run Tag
    if [ "${TAG}" == "all" ]; then

        bash scripts/00.workflow.commands.sh  1> null &

    else

        bash scripts/tags_scripts/${TAG}.sh 1> null &

    fi

}



