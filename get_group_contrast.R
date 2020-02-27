#!/usr/bin/env Rscript


# A simple script to get all possible contrasts between levels in a factor to be used with the DeSeq2 module of NetSeqFlow
# AUTHOR : Olabiyi Obayomi
##### USAGE
#SYNOPSIS
# Rscript get_group_contrast.R <mapping_file> <factor_column>

# Example

# Rscript get_group_contrast.R sample_grouping.txt Treatment

# RETURNS:
# A pipe (|) separated string of all possible contrasts
###################################


args <- commandArgs(trailingOnly =T)

mapping_file <- args[1]
factor_column <- args[2]

# DEBUGING
#print(mapping_file)
#print(factor_column)

df <- read.table(mapping_file,header=T, comment.char = '')

# Get the unique levels of the factor column
levels <- unique(as.character(df[,factor_column]))

# Get all pairwise combinations of the factor
combinations <- utils::combn(levels,2)

# Paste the factor column name and every element in each column seperated by commas
comparisons <- apply(X = combinations, MARGIN = 2, FUN = function(column) paste0(factor_column,',',paste(column,collapse = ",")))


# Paste together the elements of comparison separated by pipe in preparation for DeSeq2 module and print to standard output

print(paste(comparisons, collapse = '|'))

