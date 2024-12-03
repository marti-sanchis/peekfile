#!/usr/bin/env bash
###############################################   INITIALISING SOME VARIABLES   #################################################
shopt -s expand_aliases		# Enable the use of aliases in the script
alias echo="echo -e"		# Setting the option -e as default for echo, which enables the use of newline character

# Default variables
path="$PWD"
N=0
show_help=false			# A boolean variable to control for help info.

##########################################   HELP FASTASCAN: INFO ABOUT THE FUNCTION   ##########################################
# This will be printed if the option -h is used (and so $show_help is true): fastascan.ai -h.
show_usage() {
    echo "\nUse: $(basename $0) [options]"
    echo "Options:"
    echo "  -d <directory>    Specify the directory to scan. Subdirectories are also scanned."
    echo "  -n <n lines>      Specify number (integer) of first and last lines to show for each file."
    echo "  -h                Show usage."
    echo "\n# If no options are provided, the current directory and 0 lines are used by default.\n"
    exit 0
}
#########################################################   ARGUMENTS   #########################################################
# ChatGPT suggestion:
# The command getopts allows the use of flags as options to provide arguments. It recives a string of possible options: ":d:n:h"
# The first ":" indicates silent mode, meaning don't show std error; i.e. controll error manually indicating what to do in case :)
# d: and n: indicate that these are possible options that require an argument
# The last h indicates a possible option with no argument
# Variable Opt is updated with every new valid option read by getopts.
# The case is used to decide what to do based on what option has been provided by the user.
while getopts ":d:n:h" opt; do
    case "$opt" in
	d)	# When option detected is -d, check if the argument provided ($OPTARG) is valid and update $path.							
		if [[ -z "$OPTARG" || "$OPTARG" == -* ||  ! -d "$OPTARG" ]]; then
			echo "\nERROR: Argument provided to option -d is not a valid directory.\n++ Use $(basename $0) -h for more info.\n"
			exit 1
		fi
		path=$(realpath "$OPTARG")							
		;;
	n)	# When option detected is -n, check if argument provided is valid and update $N
		if [[ -z "$OPTARG" || "$OPTARG" == -* || ! "$OPTARG" =~ ^[0-9]+$ ]]; then
			echo "\nERROR: Argument provided to option -n is not an integer.\n++ Use $(basename $0) -h for more info.\n"
			exit 1
		fi
		N="$OPTARG"
		;;
	h)	# If flag -h is used, change boolean variable $show_help to true
		show_help=true									
		;;
	:)	# When no argument is provided for an option (-d or -n), give error and exit 1. In these cases, $OPTARG stores the name of the option, not a null argument.
		echo "\nERROR: Option -$OPTARG requires an argument.\n++ Use $(basename $0) -h for more info.\n"				
		exit 1
		;;
	\?)	# When using an option not contemplated, give error and exit 1.
		echo "\nERROR: Invalid option -$OPTARG"
		echo "++ Use $(basename $0) -h for more info.\n"
		exit 1
		;;
    esac
done

# Control for the case a positional argument is provided without an option. 
if [[ -n "$1" && ! "$1" =~ ^- ]]; then	
	echo "\nERROR: Arguments must be passed after an option, not as a positional argument."
	echo "++ Use $(basename $0) -h for more info.\n"
	exit 1
fi

# Show help if variable show_help has been changed to true, and don't print settings. Else, show settings.
if $show_help; then		
    show_usage			
else
# Print the settings for the scan
	echo -e "\nSETTINGS:"
	echo "# Scanning directory "$path" and subdirectories."						
	echo "# N set to "$N" lines."

fi
####################################   SCANNING DIRECTORY AND SUBDIRECTORIES FOR FA/FASTAS   ####################################
#--------------------------------------------   Functions controlling for header  -----------------------------------------------
# Function to print first and last N lines of a file if there are 2N+ lines of content, if less print full content.
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
# ChatGPT suggestion:
# Function for spacing headers with same lenght. It will take as arguments: $1 a fixed total length of the header. $2 the variable $file in a while read loop
padding() {						
    name="Filename: $(basename "$2")"				
    total_length=$(( ${#name} + 24 ))				# Store the minimum total length of the header: take the longitude of name and add the space of fixed characters
    if (( total_length < "$1" )); then				
        extra_spaces=$(("$1" - total_length))			# Compute the amount of spaces needed to reach fixed total length.
        left_padding=$((extra_spaces / 2))			# Divide it by 2 and assign it to the left padding. 
        right_padding=$((extra_spaces - left_padding))		# Take the rest for right_padding
    else
        left_padding=0						# If header is already equal or greater than fixed total length, just leave it like that.
        right_padding=0
    fi
    printf "%s" "########### "					
    printf "%*s" $left_padding ""  				# Print a string of N=$left_padding spaces. The * enables the use the number of elements to repeat
    printf "%s" "$name"					
    printf "%*s" $right_padding ""  				# Print spaces to the right. 
    printf "%s\n" " ###########"				# Also add final \n
}

#------------------------------------------------   FASTA count and unique   ----------------------------------------------------
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

# ChatGPT suggestion: filter out broken symlinks and files without read permissions. Store the filename in vfiles with a newline.
# Second conditions is written with -e test because both, files without permissions and broken symlinks, are detected as non-readable. 
vfiles=""											
while read file; do
	if [[ -e "$file" && -r "$file" ]]; then							
        	vfiles="$vfiles$file"$'\n'								
        elif [[ -e "$file" ]]; then									
		echo "-- Warning: file $(basename "$file") is not readable. It will be ignored."
	else											
        	echo "-- Warning: file $(basename "$file") is a broken symlink. It will be ignored."
	fi
done <<< "$files"			# Need to redirect input like this. Using while read with cat + pipe, a subshell is used and the list vfiles is not saved outside of it.
vfiles=$(echo "$vfiles" | head -n -1)	# Eliminate the last line generated by inserting the newline after every valid file.

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
length=80	# Set max length of headers
echo "$vfiles" | while read file; do								 

# Print the header

	padding "$length" "$file"
	
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
	cleanseq=$( { awk '!/^>/{ORS="";print}' < "$file" | sed 's/[^A-Za-z]//g'; } 2>/dev/null) || {		
		echo "ERROR: Failed to clean the sequence. Skipping file."			# ChatGPT: If there is an error, silence it by redirecting std error to dev/null.
		continue									# Skip file if no clean sequence is retrieved
	}												
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
    		echo "# Sequence type not recognised"						# If everything was negative, print unable to identify type of seq.
	fi

# Finally print the content of file using the peek() function.
	peek "$file" "$N"
	echo # add a final newline
done
