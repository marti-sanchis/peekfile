#!/usr/bin/env bash

shopt -s expand_aliases		# Enable de use of aliases in the script.
alias echo="echo -e"		# Setting the option -e as default for echo, which enables the use of newline character

##########################################   HELP ARGUMENT: INFO ABOUT THE FUNCTION   ###########################################
if [[ "$1" == "help" ]];	# If argument provided is help, show usage.
then
echo "\n# This function has the form fastascan <arg1> <arg2>, and so it has two optional independent arguments:"
echo "       - arg1. search directory, as an existing absolute path or relative path from current path."
echo "       - arg2. number of lines to print for each file, as a positive integer."
echo "\n# Either variable can be set as the only argument and the other will be set by default."
echo "# Both arguments can be omitted and will be set by default to current directory and 0 lines."
echo "# However, when the two arguments are provided, they must follow the order indicated: search directory in arg1 and number of lines in arg2.\n"
exit 0
fi
#########################################################   ARGUMENTS   #########################################################
#-----------------------------------------------   Functions printing settings  -------------------------------------------------
# The intention with this function is to reduce a bit the use of echo in argument assignment.
print_set(){
	echo "# Scanning directory "$1" and subdirectories."
	echo "# N set to "$N" lines." 
}
#--------------------------------------------   Setting directory and N correctly   ---------------------------------------------
# Initialise variables by default
path="$PWD"
N=0
echo "\nSETTINGS:"

# If two arguments are provided (should be $1=D and $2=N): 
if [[ -n "$1" && -n "$2"  ]]; then							
	[[ "$1" =~ ^[0-9] && ("$2" =~ .*/.* || "$2" == \.) ]] && {	# if order is wrong, print error and exit 1.
		echo "\nERROR: Arguments are reversed.\n++ Use fastascan help for more info.\n" 
		exit 1
	}			
	if [[ -d "$1" && "$2" =~ ^[0-9]+$ ]]; then			# If $1 is a valid directory and $2 N a positive integer, set variables. If not show error and exit 1.				
		path=$(realpath "$1")
		N="$2"
		print_set "$path" "$N"
	else										
		echo "\nERROR: arg1 is not an existing directory and/or arg2 is not a correct number of lines.\n++ Use fastascan help for more info.\n" 
		exit 1
	fi

# If only one argument is provided: detect if it's directory or integer (if other show error and exit 1) and set the correct variable with this value, and set the other by default.
elif [[ -n "$1" && -z "$2" ]]; then							
	if [[ -d "$1" ]]; then
		path=$(realpath "$1")
		print_set "$path" "$N"
	elif [[ "$1" =~ ^[0-9]+$ ]]; then
		N="$1"
		print_set "$path" "$N"
	else
		echo "\nERROR: arg1 is not an existing directory or a correct number of lines.\n++ Use fastascan help for more info.\n" 
		exit 1
	fi
# If no arguments are provided, use default values for the variables. They might not be provided because user don't know the syntax, print help.
else
	print_set "$path" "$N"
 	echo "++ Don't know the arguments? Use fastascan help for more info."
fi
####################################   SCANNING DIRECTORY AND SUBDIRECTORIES FOR FA/FASTAS   ####################################
#--------------------------------------------   Functions controlling for header  -----------------------------------------------
# Function to print first and last N lines of a file if content has 2N+ lines, if less print full content.
# This function will have two arguments: $1 is the file to cat, and $2 is N.
peek(){											
	print_N="$2" 
	total_lines=$(wc -l < "$1")							
	[[ "$print_N" -eq 0 ]] && return						# If file has no content, leave the function for this file and don't print anything
	if [[ "$total_lines" -le $((2 * "$print_N")) ]]; then				# If the total lines is less than 2N, print the whole content of the file.
		cat "$1"
		echo "# Full content of the file."
	else										# If not, just print the first and last N lines of $file 
  		echo "\n# Showing the first and last "$print_N" lines of the file."
		head -n "$print_N" "$1"
		echo "..."
		tail -n "$print_N" "$1" 
	fi
}
#------------------------------------------------   FASTA count and unique   ----------------------------------------------------
# NOTE!!: here I didn't account for broken symlink or files without permissions, and chatgpt suggested it for fastascan.ai.
# These files are counted in total fasta files, and don't affect to the uniqID computation, as only std input is passed through pipes. However some std error is printed.
echo "\nSCAN RESULTS:"

# Do only one search, for files or symlinks that are fa/fasta. 
files=$(find "$path" \( -type f -o -type l \) \( -name "*.fa" -or -name "*.fasta" \) )	
[[ -z "$files" ]] && {									# If bash doesn't find any fasta (tested as $files is null?), exit 0
	echo "# No fasta files have been found in "$path" and subdirectories.\n"	
	exit 0
}
# Count how many are there. With quotation of $files, output is not squished to one line.
fastacount=$(echo "$files" | wc -l)							
echo "# Count of files: "$fastacount""

# Compute the total number of unique IDs in all files. 
# Create a temporal file to store all content, using while read which enebales correct read of spaces in filenames (can't use cat $files, which requires no quotation)
temp_file=$(mktemp)									# Command mktemp creates a temporal file in path /temp, and prints the name
echo "$files" | while read file; do 							
	cat "$file"									
done > "$temp_file"									
uniqID_total=$(cat "$temp_file" | awk '/>/{print $1}' | sort | uniq | wc -l)		# Cat all files, get all non-header lines, print seq ID, get how many unique IDs there are.
rm "$temp_file"										
echo "# Total unique sequence IDs: "$uniqID_total".\n"					

#-----------------------------------------------------   FASTA header   ---------------------------------------------------------
# Iterate for every fasta found. Print a header with the filename.
echo "$files" | while read file; do											
	echo "########### Filename: $(basename "$file") ###########"
	
# Check if the file is a symlink with -h condition
	if [[ -h "$file" ]]; then							
		echo "# Is this a symlink? YES"
	else
		echo "# Is this a symlink? NO"
	fi
	
# Count the number of headers in the file
	seqcount=$(grep -c "^>" "$file")
	echo "# Count of sequences: "$seqcount""
	
# If the file doesn't contain any header, omit the rest of operations (skip iteration).
	[[ "$seqcount" == 0 ]]  && (echo ) && continue
	
# Cleaning the sequences and merging them. Cat $file, with awk get non-headers, print everything using nothing as separator (ORS=""). With sed eliminate everything but letters
	cleanseq=$(cat "$file" | awk '!/^>/{ORS="";print}' | sed 's/[^A-Za-z]//g')
	seqlength=$(echo -n "$cleanseq" | wc -c)
	echo "# Total length of sequences: "$seqlength""
		
# Determine the type of sequence. Methionine should be present in every protein, but include lysine (more aboundant than M) just in case it's a fragment of protein.
# If no T,M,K, should be ARN. No U,M,K should be ADN. If contains M,K should be PROTEIN.
	if [[ ! $(echo -n "$cleanseq") =~ [TtMmKk] ]]; then				
    		echo "# Sequence type: ARN"
    	elif [[ ! $(echo -n "$cleanseq") =~ [UuMmKk] ]]; then				
    		echo "# Sequence type: ADN"
    	elif [[ $(echo -n "$cleanseq") =~ [MmKk] ]];then
    		echo "# Sequence type: PROTEIN"						
    	else
    		echo "# Sequence type not recognised"					# If everything was negative, print unable to identify type of seq.
	fi
	
# Finally print the content of file using the peek() function.
	peek "$file" "$N"
	echo # add a final newline
done
