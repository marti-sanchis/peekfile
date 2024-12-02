#!/usr/bin/env bash

##########################################   HELP ARGUMENT: INFO ABOUT THE FUNCTION   ###########################################
shopt -s expand_aliases		# Enable de use of aliases in the script.
alias echo="echo -e"		# Setting the option -e as default for echo, which enables the use of newline character

if [[ "$1" == "help" ]];	# If argument provided is help, show usage.
then
echo "\n# This function has the form fastascan <arg1> <arg2>, and so it has two optional independent arguments:"
echo "       - arg1. search directory, as an existing absolute path or relative path from current path."
echo "       - arg2. number of lines to print for each file, as an integer."
echo "\n# Either arg1 or arg2 can be set as the only argument and the other will be set by default."
echo "# Both arguments can be omitted and will be set by default to current directory and 0 lines."
echo "# However, when the two arguments are provided, they must follow the order indicated: search directory in arg1 and number of lines in arg2.\n"
exit 0
fi
#########################################################   ARGUMENTS   #########################################################
#-------------------------------------------   Function for errors in the arguments  --------------------------------------------
# The intention of this function is to make clearer the assignment of variables later on.
# Basically it is considering 3 cases in which arguments are provided wrongly or are not valid.
# 1) Both arguments are provided and one of them or both is invalid.
# 2) Only one argument is provided and is not valid.
# 3) Both arguments are provided with wrong order.
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
#-----------------------------------------   Functions controlling for the arguments  -------------------------------------------
# These two functions also try to make clearer the assignment of variables later on.
# Set_path sets variable $path as the absolute path of the argument if it is not null. If it is provided as null, use $PWD instead. It also prints clarfying message to screen.
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
# Set_N sets the variable $N for printing lines. Basically it's only to print to screen the settings. 
set_N(){
	[[ $1 -gt 0 ]] && {
		N="$1"
		echo "# Printing the first and last "$N" lines of each fasta file.\n"
	} || {
		N=0
		echo "# No lines printed by default.\n"
	}
}
#--------------------------------------------   Setting directory and N correctly   ---------------------------------------------
if [[ -n "$1" && -n "$2"  ]]; then					# If two arguments are provided (should be directory and N)
	[[ "$1" =~ ^[0-9] && ("$2" =~ .*/.* || "$2" == \.) ]] && err 3	# ensure they are in the correct order. If not print error 3 from err() which stops the script
	if [[ -d "$1" && "$2" =~ ^[0-9]+$ ]]; then			# If $1 is an existing directory and $2 an integer, set path and set N variables.
		set_path "$1"
		set_N "$2"
	else								# If not, give error 1 from err(): one or both arguments are not valid.
		err 1
	fi
	
elif [[ -n "$1" && -z "$2" ]]; then					# If only one argument is provided... 
	if [[ -d "$1" ]]; then						# see if it is a directory and set path with the argument, and N by default.
		set_path "$1"
		set_N 0
	elif [[ "$1" =~ ^[0-9]+$ ]]; then				# see if it is an integer and set path by default and N with the argument.
		set_path "" 
		set_N "$1"
	else
		err 2
	fi
else
	set_path "" 							# If no arguments are provided, use set_path and set_N to use default values for the variables.
	set_N 0
fi
####################################   SCANNING DIRECTORY AND SUBDIRECTORIES FOR FA/FASTAS   ####################################
#--------------------------------------------   Functions controlling for header  -----------------------------------------------
peek(){									# This function will have two arguments: $1 is the file to cat, and $2 a number of lines
	print_N="$2" 
	total_lines=$(wc -l < "$1")					# Set a variable with the total number of lines in a file provided as < $file to command wc -l
	
	[[ "$print_N" -eq 0 ]] && return				# If N=0, skip the iteration for this file and don't print anything
	
	if [[ "$total_lines" -le $((2 * "$print_N")) ]]; then		# If the total lines is less than 2N, print the whole content of the file.
		cat "$1"
		echo "# Full content of the file."
	else								# If not, just print the first and last N lines of $file with commands head and tail (separated by ...)
  		echo "\n# Showing the first and last "$print_N" lines of the file."
		head -n "$print_N" "$1"
		echo "..."
		tail -n "$print_N" "$1" 
	fi
}
#------------------------------------------------   FASTA count and unique   ----------------------------------------------------
echo "SCAN RESULTS:"
# Do only one search, for files or symlinks that are fa/fasta. Assign to variable $files.
files=$(find "$path" \( -type f -o -type l \) \( -name "*.fa" -or -name "*.fasta" \) )

# If bash finds any fasta (tested as $files is not null?)...
if [[ -n "$files" ]]; then
	fastacount=$(echo "$files" | wc -l)						# Count how many are there. With quotation of var, output is not squished to one line.
# Compute the total number of unique IDs in all valid files.
	uniqID_total=$(cat $files | awk '/>/{print $1}' | sort | uniq | wc -l)		# Cat all files, get all non-header lines, print seq ID, get how many unique IDs there are
else											# If $files is null, exit 0 (consistent with find exit code for not finding files)
	echo "# No fasta files have been found in "$path" and subdirectories.\n"
	exit 0
fi

echo "# Count of files: "$fastacount""
echo "# Total unique sequence IDs: "$uniqID_total".\n"


#-----------------------------------------------------   FASTA header   ---------------------------------------------------------
# Iterate for every fasta found. 
# NOTE: here I didn't controll for broken symlink, and chatgpt suggested it for fastascan.ai.  
# NOTE: moreover, I didn't consider the case for files without permissions. I account for that also in fastascan.ai.
echo "$files" | while read file; do					
	echo "########### Filename: $(basename "$file") ###########" 			# Print a header with the filename
	
	# Check if the file is a symlink
	if [[ -h "$file" ]]; then							# Check if the file is a symlink with -h condition
		echo "# Is this a symlink? YES"
	else
		echo "# Is this a symlink? NO"
	fi
	
	# Count the number of headers in the file
	seqcount=$(grep -c "^>" $file)							# Count with grep -c the number of headers/sequences in the file
	echo "# Count of sequences: "$seqcount""
	
	# If the file doesn't contain any header, omit the rest of operations (skip iteration).
	[[ "$seqcount" == 0 ]]  && (echo ) && continue
	
	# Cleaning the sequences and merging them.
	cleanseq=$(cat "$file" | awk '!/^>/{ORS="";print}' | sed 's/[^A-Za-z]//g')	# Cat $file, with awk get non-headers, print everything using nothing as separator (ORS="") 
											# With sed eliminate everything but letters (case insensitive)
	seqlength=$(echo -n "$cleanseq" | wc -c)					# Get the total length of $cleanseq (containing all sequences in the file)
	echo "# Total length of sequences: "$seqlength""
		
	# Determine the type of sequence
	if [[ ! $(echo -n "$cleanseq") =~ [TtKk] ]]; then				# If sequence doesn't contain thymine or lysine it should be ARN
    		echo "# Sequence type: ARN"
    	elif [[ ! $(echo -n "$cleanseq") =~ [UuKk] ]]; then				# If sequence doesn't contain uracil or lysine it should be ADN
    		echo "# Sequence type: ADN"
    	else										# If not ADN or ARN, sequence should be from protein.
    		echo "# Sequence type: PROTEIN"
	fi
	
# Finally print the content of file using the peek() function.
	peek "$file" "$N"
	echo # add a final newline
done
