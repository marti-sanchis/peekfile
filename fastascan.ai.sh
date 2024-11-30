#!/usr/bin/env bash

##########################################   HELP ARGUMENT: INFO ABOUT THE FUNCTION   ###########################################
shopt -s expand_aliases  # Habilita l'ús de alias al script
alias echo="echo -e"

if [[ "$1" == "help" ]]; 
then
echo "\n# This function has the form fastascan <arg1> <arg2>, and so it has two optional independent arguments:"
echo "       - arg1. search directory, as an existing absolute path or relative path from current path."
echo "       - arg2. number of lines to print for each file, as an integer."
echo "\n# Either arg1 or arg2 can be set as the only argument and the other will be set by default."
echo "# Both arguments can be omitted and will be set by default to current directory and 0 lines."
echo "# However, when the two arguments are provided, they must follow the order indicated: search directory in arg1 and number of lines in arg2.\n"
echo "# EXIT CODE: "
echo "      - Exit 10 corresponds to setting two arguments and one or both are wrong."
echo "      - Exit 11 corresponds to setting one wrong argument."
echo "      - Exit 12 corresponds to setting two arguments in wrong order.\n"
exit 0
fi

####################################################   FUNCTION FOR ERRORS   ####################################################

err(){
	err_flag="$1"
	[[ "$err_flag" -eq 1 ]] && {
		echo "\nERROR: arg1 is not an existing directory and/or arg2 is not a correct number of lines." 
		echo "++ Use fastascan help for more info.\n"
		exit 1
	} || [[ "$err_flag" -eq 2 ]] && {
		echo "\nERROR: arg1 is not an existing directory or a correct number of lines." 
		echo "++ Use fastascan help for more info.\n"
		exit 1
	} || [[ "$err_flag" -eq 3 ]] && {
		echo "\nERROR: Arguments are reversed." 
		echo "++ Use fastascan help for more info.\n"
		exit 1
	}
}
#################################################   CONTROL FOR THE ARGUMENTS   #################################################
#------------------------------------------   Functions for setting directory and N  --------------------------------------------

set_path(){
	[[ -n "$1" ]] && {
		path=$(realpath "$1")
		echo -e "\nSETTINGS:"
		echo "# Scanning directory "$path" and subdirectories."
	} || {
		path="$PWD"
		echo -e "\nSETTINGS:"
		echo "# Scanning current directory and subdirectories by default."
	}
}

set_N(){
	[[ $1 -gt 0 ]] && {
		N="$1"
		echo "# Printing the first and last "$N" lines of each fasta file.\n"
	} || {
		N=0
		echo "# No lines printed by default.\n"
	}
}

peek(){
	print_N="$2" 
	total_lines=$(wc -l < "$1")
	
	[[ "$print_N" -eq 0 ]] && return
	
	if [[ "$total_lines" -le $((2 * "$print_N")) ]]; then 
		cat "$1"
		echo "# Full content of the file."
	else
  		echo "\n# Showing the first and last "$print_N" lines of the file."
		head -n "$print_N" "$1"
		echo "..."
		tail -n "$print_N" "$1" 
	fi
}

#--------------------------------------------   Setting directory and N correctly   ---------------------------------------------
if [[ -n "$1" && -n "$2"  ]]; then
	[[ "$1" =~ ^[0-9] && ("$2" =~ .*/.* || "$2" == \.) ]] && err 3 # if both arguments are provided, ensure they are in the correct order
	if [[ -d "$1" && "$2" =~ ^[0-9]+$ ]]; then
		set_path "$1"
		set_N "$2"
	else
		err 1
	fi
	
elif [[ -n "$1" && -z "$2" ]]; then
	if [[ -d "$1" ]]; then
		set_path "$1"
		set_N 0
	elif [[ "$1" =~ ^[0-9]+$ ]]; then
		set_path "" #set to null to use and print that current directory is used by default
		set_N "$1"
	else
		err 2
	fi
else
	set_path "" #set to null to use and print that current directory is used by default
	set_N 0
fi

####################################   SCANNING DIRECTORY AND SUBDIRECTORIES FOR FA/FASTAS   ####################################
#------------------------------------------------   FASTA count and unique   ----------------------------------------------------
echo "SCAN RESULTS:"

files=$(find "$path" \( -type f -o -type l \) \( -name "*.fa" -or -name "*.fasta" \) )

if [[ -n "$files" ]]; then
	fastacount=$(echo "$files" | wc -l)
	uniqID_total=$(cat $files | awk '/>/{print $1}' | sort | uniq | wc -l)
else
	echo "# No fasta files have been found in "$path" and subdirectories.\n"
	exit 0
fi

echo "# Count of files: "$fastacount""
echo "# Total unique sequence IDs: "$uniqID_total".\n"


#-----------------------------------------------------   FASTA header   ---------------------------------------------------------

echo "$files" | while read file; do
	echo "########### Filename: $(basename "$file") ###########" 
	
	# Check if the file is a symlink
	if [[ -h "$file" ]]; then
		echo "# Is this a symlink? YES"
	else
		echo "# Is this a symlink? NO"
	fi
	
	# Count the number of headers in the file
	seqcount=$(grep -c "^>" $file)
	echo "# Count of sequences: "$seqcount""
	
	# If the file doesn't contain any header, omit the rest of operations.
	[[ "$seqcount" == 0 ]]  && (echo ) && continue
	
	# Cleaning the sequences (removing headers and any character apart from letters) and merging them.
	cleanseq=$(cat "$file" | awk '!/^>/{ORS="";print}' | sed 's/[^A-Za-z]//g')
	seqlength=$(echo -n "$cleanseq" | wc -c) # Compute total length.
	echo "# Total length of sequences: "$seqlength""
		
	# Determine the type of sequence
	if [[ ! $(echo -n "$cleanseq") =~ [TtKk] ]]; then
    		echo "# Sequence type: ARN"
    	elif [[ ! $(echo -n "$cleanseq") =~ [UuKk] ]]; then
    		echo "# Sequence type: ADN"
    	else
    		echo "# Sequence type: PROTEIN"
	fi
	peek "$file" "$N"
	echo # add a final newline
done
