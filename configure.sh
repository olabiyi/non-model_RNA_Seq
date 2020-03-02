#!/usr/bin/env bash

# AUTHOR : Olabiyi Obayomi (obadbotanist@yahoo.com)
# VERSION : 1.0


set -e

USAGE="$(basename "$0") [-h] [ -m value -n value -r file path -b value] 
-- $(basename "$0"): Configures your environment and makes it ready to run the non-model organisms RNA-Seq pipeline. 

--EXAMPLE: bash "$(basename "$0")" -m 1 -n 1 -r database/rRNA_sequences.fasta -b metazoa_odb9.tar.gz 
where:
    -h  Show this help text.
    -m  Should Miniconda be installed? If set to 1, Miniconda will be installed otherwise it won't be installed. Default value is 1, it will be installed.
    -n  Should NeatSeq_Flow be installed? If set to 1, NeatSeq_Flow will be installed otherwise it won't be installed. Default value is 1, it will be installed.
    -r  File path to your rRNA sequences. These sequences will be used to build a database that will be used by bwa and samtools to filter out unwanted rRNA sequences.
    -b  Tar file name of your choice BUSCO dataset from the available BUSCO datasets.
     	Example metazoa_odb9.tar.gz. Please see the pipeline's documentation for the available options.
"

# Print usage if no arguement is passed to the script
if [ $# -eq 0 ]; then  echo; echo "$USAGE"; exit 1; fi

### Terminal Arguments ---------------------------------------------------------

# Import user arguments
while getopts ':hm:n:r:b:' OPTION; do
  case $OPTION in
    h) echo;echo "$USAGE"; exit 1;;
    m) INSTALL_MINICONDA=$OPTARG;;
    n) INSTALL_NEATSEQ_FLOW=$OPTARG;;
    r) rRNA_DATABASE=$OPTARG;;
    b) BUSCO_DATABASE=$OPTARG;;
    :) printf "missing argument for -$OPTARG\n" >&2; exit 1;;
   \?) printf "invalid option for -$OPTARG\n" >&2; exit 1;;
  esac
done

# Check missing arguments
MISSING="is missing but required. Exiting."
if [ -z ${INSTALL_MINICONDA+x} ]; then INSTALL_MINICONDA=1; fi; 
if [ -z ${INSTALL_NEATSEQ_FLOW+x} ]; then INSTALL_NEATSEQ_FLOW=1; fi; 
if [ -z ${rRNA_DATABASE+x} ]; then echo "-r $MISSING, you must provide a file with ribosomal RNA sequences."; echo; echo "$USAGE"; exit 1; fi; 
if [ -z ${BUSCO_DATABASE+x} ]; then echo "-b $MISSING, you must choose a valid BUSCO database from the available options."; echo; echo "$USAGE"; exit 1; fi; 

DIR=$PWD
echo;echo "Configuration will take a day to complete, so go do something else and from time to time check configure.log to monitor the current status."

cd $HOME

# Install Miniconda 

if [ ${INSTALL_MINICONDA} -eq 1 ]; then
    echo;echo "Installing Miniconda to your HOME directory ${HOME}."
    wget https://repo.continuum.io/miniconda/Miniconda3-4.7.12.1-Linux-x86_64.sh
    bash Miniconda3-4.7.12.1-Linux-x86_64.sh -bf
    echo;echo "Miniconda Installation complete!"
    rm -rf Miniconda3-4.7.12.1-Linux-x86_64.sh
fi


# Install Neatseq_flow env 
if [ ${INSTALL_NEATSEQ_FLOW} -eq 1 ]; then
    echo;echo "Installing Neatseq Flow..."
    curl -LO https://raw.githubusercontent.com/bioinfo-core-BGU/NeatSeq-Flow-GUI/master/NeatSeq_Flow_GUI_installer.yaml
    conda env create -f NeatSeq_Flow_GUI_installer.yaml
    echo;echo "Neatseq Flow Installation completed successfully!"
    rm -rf NeatSeq_Flow_GUI_installer.yaml
fi

echo;echo "Creating DeSeq2 conda environment..."
# Create DeSeq2 environment
wget https://raw.githubusercontent.com/bioinfo-core-BGU/NeatSeq-Flow_Workflows/master/DeSeq_Workflow/DeSeq2_module/DeSeq2_env_install.yaml
# Correct the version problem with biconductor-sva
sed -i "s/bioconductor-sva=3.8/bioconductor-sva/g" DeSeq2_env_install.yaml
conda env create -f DeSeq2_env_install.yaml
echo;echo "DeSeq2 conda environment created successfully!"
rm -rf DeSeq2_env_install.yaml

echo;echo "Creating non_model_RNA_Seq conda environment..."
# Create non_model_RNA_Seq conda environment and set it up
wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/non_model_RNA_Seq_conda.yaml
conda env create -f non_model_RNA_Seq_conda.yaml
source activate non_model_RNA_Seq
echo;echo "non_model_RNA_Seq conda environment created successfully!"
rm -rf non_model_RNA_Seq_conda.yaml

cd $DIR

# Set-up rnammer
echo;echo "Setting-up rnammer with hmm..."
# Download rnammer
wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/rnammer.tar.gz
tar -xvzf rnammer.tar.gz
sed -i "s:/usr/cbs/bio/src/rnammer-1.2:$CONDA_PREFIX/opt/RNAMMERv1.2/:g" RNAMMERv1.2/rnammer
sed -i -E "s:/usr/cbs/bio/bin/.+/:$CONDA_PREFIX/opt/hmmer-2.3.2/bin/:g" RNAMMERv1.2/rnammer
sed -i  -E "s:/usr/s?bin:$CONDA_PREFIX/bin:g" RNAMMERv1.2/rnammer

# Download hmmer v2.3.2 required by rnammer
wget http://eddylab.org/software/hmmer/2.3.2/hmmer-2.3.2.tar.gz
tar -xzvf hmmer-2.3.2.tar.gz
cd hmmer-2.3.2/
./configure --mandir=$PWD/man --bindir=$PWD/bin
make
make install
cd ..
mv RNAMMERv1.2   hmmer-2.3.2/ $CONDA_PREFIX/opt/
rm -rf rnammer.tar.gz hmmer-2.3.2.tar.gz

echo;echo "Downloading scripts customized for the non-model RNA-Seq pipeline..."
# Download scripts and files customized for the pipeline
cd $CONDA_PREFIX/bin/
wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/filter_trinity_by_counts.R
chmod +x  filter_trinity_by_counts.R
wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/BlastXMLmerge.py
chmod +x  BlastXMLmerge.py
wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/get_group_contrast.R
chmod +x  get_group_contrast.R
# Download modified RnammerTranscriptome_mod.pl that handles empty rRNA predictions
wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/RnammerTranscriptome_mod.pl
chmod +x RnammerTranscriptome_mod.pl
# Download job limit file
wget https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/job_limit.txt

echo "Setting-up BUSCO..."
# Edit BUSCOs config.ini.default 
sed -i -E 's/;mode = genome/mode = transcriptome/g' $CONDA_PREFIX/share/busco-3.0.2-8/config.ini.default
sed -i -E "s:/usr/bin/:$CONDA_PREFIX/bin/:g" $CONDA_PREFIX/share/busco-3.0.2-8/config.ini.default
cd ..

echo;echo "Creating databases..."
# Make a directory in the current directory to store databases
[ -d databases ] || mkdir databases/
cd databases/

# Download databases
# Trinotate databases - https://github.com/Trinotate/Trinotate.github.io/wiki/Software-installation-and-data-required
[ -d Trinotate ] || mkdir Trinotate/
cd Trinotate/
export PERL5LIB=$CONDA_PREFIX/lib/site_perl/5.26.2/
echo;echo "Building Trinotate databases..."
Build_Trinotate_Boilerplate_SQLite_db.pl  Trinotate
makeblastdb -in uniprot_sprot.pep -dbtype prot
gunzip Pfam-A.hmm.gz
hmmpress Pfam-A.hmm
echo;echo "Done building Trinotate databases!"
cd ..

# Create Refseq proteins database
[ -d Refseq ] || mkdir Refseq/
cd Refseq/
echo;echo "Downloading Refseq protein sequences..."
wget ftp://ftp.ncbi.nlm.nih.gov/refseq/release/complete/*faa.gz
echo;echo "Unzipping the sequences..."
gunzip *.gz
echo;echo "Concatenating the sequences to refseq_protein.faa"
cat *.faa > refseq_protein.faa
echo;echo "Making refseq_protein database..."
makeblastdb -in refseq_protein.faa -out refseq_protein -dbtype prot
echo;echo "Cleaning up..."
rm -rf *faa
echo;echo "Done building refseq_protein database!"
cd ..

[ -d rRNA ] || mkdir rRNA/
cd rRNA/
# rRNA database
# Get rRNA sequences from the file path supplied and build the bwa index
echo;echo "Building ribosomal RNA database..."
DATABASE_NAME=$(basename ${rRNA_DATABASE} | sed -E 's/\..+$//g')
bwa index -p ${DATABASE_NAME}  -a bwtsw ${rRNA_DATABASE} #|| echo "You have not provided valid sequences for the construction of your rRNA database. Make sure you prepare and copy it to  $CONDA_PREFIX/databases/rRNA/"
echo;echo "Done building ribosomal RNA database!"
cd ..

[ -d  BUSCO ] || mkdir BUSCO/
cd BUSCO/
# Download BUSCO_lineage dataset
echo;echo "Downloading your BUSCO database..."
wget http://busco.ezlab.org/v2/datasets/${BUSCO_DATABASE}
tar -xvzf ${BUSCO_DATABASE}
rm -rf ${BUSCO_DATABASE}
echo;echo "Done building BUSCO database!"
cd ..

cd $DIR 
# Download the template non_model_RNA_Seq.yaml parameter file
wget  https://raw.githubusercontent.com/olabiyi/non-model_RNA_Seq/master/non_model_RNA_Seq.yaml

echo;echo "Done! Your environment was configured successfully." 
echo;echo "The path to to your non_model_RNA_Seq conda environment is : $CONDA_PREFIX ."
echo;echo "Your template parameter file is non_model_RNA_Seq.yaml. You can edit it as you please but do not change any capitalized text in the file."
source deactivate 
