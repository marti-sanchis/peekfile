#!/usr/bin/env bash
###############################################   INITIALISING SOME VARIABLES   #################################################
shopt -s expand_aliases  # Habilita l'ús de alias al script
alias echo="echo -e"

# Default variables
path=""
N=0
show_help=false

##########################################   HELP FUNCTION: INFO ABOUT THE FUNCTION   ###########################################
show_usage() {
    echo "Use: $0 [options]"
    echo "Options:"
    echo "  -d <directory>    Specify the directory to scan. Subdirectories are also scanned."
    echo "  -n <n lines>      Specify number (integer) of first and last lines to show for each file."
    echo "  -h                Show usage."
    exit 0
}
#########################################################   FUNCTIONS   #########################################################
#-------------------------------------------   Function for errors in the arguments  --------------------------------------------
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
#--------------------------------------------   Functions controlling for header  -----------------------------------------------
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

padding() {
    name="Filename: $(basename "$2")"
    total_length=$(( ${#name} + 14 ))  
    if (( total_length < "$1" )); then
        extra_spaces=$(("$1" - total_length))
        left_padding=$((extra_spaces / 2))
        right_padding=$((extra_spaces - left_padding))
    else
        left_padding=0
        right_padding=0
    fi
    printf "%s" "########### "
    printf "%*s" $left_padding ""  
    printf "%s" "$name"
    printf "%*s" $right_padding ""  
    printf "%s\n" " ###########"
}

#########################################################   ARGUMENTS   #########################################################
#--------------------------------------------   Setting directory and N correctly   ---------------------------------------------
while getopts "d:n:h" opt; do
    case "$opt" in
        d) path="$OPTARG" ;;  # Set path variable with argument after -d
        n) N="$OPTARG" ;;      # Set number of lines with argument after -n
        h) show_help=true ;;       # Activate help
        *) show_usage ;;           # Show help in case of invalid arguments
    esac
done

# Show help if demanded
if $show_help; then
    show_usage
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
length=60
echo "$files" | while read file; do
	padding "$length" "$file" 
	
	# Check if the file is a symlink
	if [[ -h "$file" ]]; then
		echo "# Is this a symlink? YES"
		[[ ! -e "$file" ]] && echo "# This symlink is broken.\n" && break # ChatGPT correction:
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
