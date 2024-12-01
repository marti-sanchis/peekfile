#!/usr/bin/env bash
###############################################   INITIALISING SOME VARIABLES   #################################################
shopt -s expand_aliases		# Enable the use of aliases in the script
alias echo="echo -e"		# Setting the option -e as default for echo, which enables the use of newline character

# Default variables
path="$PWD"
N=0
show_help=false			# A boolean variable to control for help info.

##########################################   HELP FASTASCAN: INFO ABOUT THE FUNCTION   ##########################################
show_usage() {
    echo "Use: $(basename $0) [options]"
    echo "Options:"
    echo "  -d <directory>    Specify the directory to scan. Subdirectories are also scanned."
    echo "  -n <n lines>      Specify number (integer) of first and last lines to show for each file."
    echo "  -h                Show usage."
    echo "\n# If arguments for -d and -n are not provided, the current directory and 0 lines are used by default."
    exit 0
}
#########################################################   ARGUMENTS   #########################################################
# ChatGPT suggestion:
# The command getopts allows the use of flags as options to provide arguments. It recives a string of possible options:
# In the string, the first : indicates silent mode, meaning errors are controlled manually. 
# d: and n: indicate that these are possible options to give argument
# The last h indicates a possible option with no argument
# Variable Opt is set with every new valid option read by getopts.
# The case is used to decide what to do based on what option has been provided by the user.
while getopts ":d:n:h" opt; do
    case "$opt" in
	d)											# When option detected is -d (for directory to scan)
		if [[ -z "$OPTARG" || "$OPTARG" == -* ||  ! -d "$OPTARG" ]]; then		# If the argument provided ($OPTARG) is not a valid, give an error and exit 1.
			echo "\nERROR: Argument provided to option -d is not a valid directory."
			echo "++ Use $(basename $0) -h for more info.\n"
			exit 1
		fi
		path=$(realpath "$OPTARG")							# If not, update $path (which was $PWD by default) with the absolute path provided
		;;
	n)											# When option detected is -n (number of first and last lines to print)
		if [[ -z "$OPTARG" || "$OPTARG" == -* || ! "$OPTARG" =~ ^[0-9]+$ ]]; then	# If the argument provided is not valid, give error and exit 1.
			echo "\nERROR: Argument provided to option -n is not an integer."
			echo "++ Use $(basename $0) -h for more info.\n"
			exit 1
		fi
		N="$OPTARG"									# If not, update variable $N (which was 0 by default) with the integer provided
		;;
	h)
		show_help=true									# If flag -h is used, change boolean variable $show_help to true
		;;
	:)											# When no argument is provided for an option (-d or -n), give error and exit 1.
		echo "\nERROR: Option -$OPTARG requires an argument."				# In these cases, $OPTARG stores the name of the option, not a null argument.
		echo "++ Use $(basename $0) -h for more info.\n"
		exit 1
		;;
	\?)											# When using an option not contemplated, give error and exit 1.
		echo "\nERROR: Invalid option -$OPTARG"
		echo "++ Use $(basename $0) -h for more info.\n"
		exit 1
		;;
    esac
done

# Print the settings for the scan
echo -e "\nSETTINGS:"
echo "# Scanning directory "$path" and subdirectories."				# Show path being scanned

if [[ "$N" -ne 0 ]]; then							# Give different grammar for cases N=0 and N!=0.
	echo "# Printing the first and last "$N" lines of each fasta file.\n"
else
	echo "# No lines printed.\n"
fi
		
if $show_help; then		# Show help if variable show_help has been changed to true in argument input
    show_usage			# Call function that shows usage
fi

####################################   SCANNING DIRECTORY AND SUBDIRECTORIES FOR FA/FASTAS   ####################################
#--------------------------------------------   Functions controlling for header  -----------------------------------------------
peek(){								# This function will have two arguments: $1 is the file to cat, and $2 a number of lines
	print_N="$2"
	total_lines=$(wc -l < "$1")				# Set a variable with the total number of lines in a file provided as < $file to command wc -l
	[[ "$print_N" -eq 0 ]] && return			# If N=0, skip the iteration for this file and don't print anything
	
	if [[ "$total_lines" -le $((2 * "$print_N")) ]]; then	# If the total lines is less than 2N, print the whole content of the file.
		echo "# Full content of the file."
		cat "$1"
	else							# If not, just print the first and last N lines of $file with commands head and tail (separated by ...)
  		echo "\n# Showing the first and last "$print_N" lines of the file."
		head -n "$print_N" "$1"
		echo "..."
		tail -n "$print_N" "$1" 
	fi
}
# ChatGPT suggestion:
padding() {							# Function for spacing the headers with same lenght for every filename (just for aesthetics)
								# It will take as arguments: $1 a maximum total length of the header. $2 the variable $file in a while read loop
    name="Filename: $(basename "$2")"				# Store what will be printed as header. Filename: "short name of the file".
    total_length=$(( ${#name} + 24 ))				# Store the minimum total length of the header: take the longitude of name and add the space of fixed characters
    if (( total_length < "$1" )); then				# If this variable is less than the maximum length specified $1, it will add spaces evenly to the name to reach $1
        extra_spaces=$(("$1" - total_length))			# Compute the amount of spaces needed to reach $1
        left_padding=$((extra_spaces / 2))			# Divide it by 2 and assign it to the left padding. 
        right_padding=$((extra_spaces - left_padding))		# Assign the rest to the right padding. If extra_spaces is odd number, right padding will have 1 more space.
    else
        left_padding=0						# If the minimum length of the header is already equal or greater than total_length, just leave it like that.
        right_padding=0
    fi
    printf "%s" "########### "					# Add a fixed amount of characters: 11 # with one space.
    printf "%*s" $left_padding ""  				# Print a string of N ($left_padding) spaces in the same line. The * enables the use the number of elements to repeat
    printf "%s" "$name"						# Print name in the same line.
    printf "%*s" $right_padding ""  				# Print a string of N ($right_padding) spaces. 
    printf "%s\n" " ###########"				# Add a fixed amount of characters: one space with 11 #. Add a newline at the end.
}

#------------------------------------------------   FASTA count and unique   ----------------------------------------------------
echo "SCAN RESULTS:"
files=$(find "$path" \( -type f -o -type l \) \( -name "*.fa" -or -name "*.fasta" \) )	# Do only one search, for files or symlinks that are fa/fasta. Assign to variable $files.

# If bash doesn't find any fasta (tested as $files is null?), exit 0 (following find exit code for not finding files)
[[ -z "$files" ]] && {
	echo "# No fasta files have been found in "$path" and subdirectories.\n"	
	exit 0
}

# ChatGPT suggestion: clean the list of found fastas out from broken symlinks
vfiles=""									# Initialise a list of verified files
for file in $files; do								# For every fasta file found
    if [[ -e "$file" ]]; then  							# Check if it exists. Basically will test false for broken symlinks, as other files found do exist.
        vfiles="$vfiles$file"$'\n'						# If positive, store the filename in vfiles with a newline.
    else
        echo "# Warning: file $(basename "$file") is a broken symlink. It will be ignored."
    fi
done
vfiles=$(echo "$vfiles" | head -n -1)						# Eliminate the last line generated by inserting the newline after every valid file.

# If variable $files is not null, meaning one ore more fastas were found...
fastacount=$(echo "$vfiles" | wc -l)						# Count how many are there. With quotation of var, output is not squished to one line.

# Compute the total number of unique IDs in all valid files.
uniqID_total=$(cat $vfiles | awk '/>/{print $1}' | sort | uniq | wc -l)		# Cat all files, get all non-header lines, print seq ID, get how many unique IDs there are

# Print the number of fasta files encountered and the total number of unique sequence IDs
echo "# Count of files: "$fastacount""							
echo "# Total unique sequence IDs: "$uniqID_total".\n"


#-----------------------------------------------------   FASTA header   ---------------------------------------------------------
length=80									# Set max length of headers
echo "$vfiles" | while read file; do						# Iterate for every fasta found. 

# Print the header
	padding "$length" "$file"
	
# Check if symlink
	if [[ -h "$file" ]]; then						# Check if the file is a symlink with -h condition
		echo "# Is this a symlink? YES"
	else
		echo "# Is this a symlink? NO"
	fi
	
# Count headers
	seqcount=$(grep -c "^>" $file)						# Count with grep -c the number of headers/sequences in the file
	echo "# Count of sequences: "$seqcount""
	[[ "$seqcount" == 0 ]]  && (echo ) && continue				# If the file doesn't contain any header, omit the rest of operations.
	
# Cleaning the sequences ($cleanseq). Get total seq length.

	cleanseq=$(awk '!/^>/{ORS="";print}' < "$file" | sed 's/[^A-Za-z]//g')	# Cat $file, with awk get non-headers, print everything using nothing as separator (ORS="") 
										# With sed eliminate everything but letters (case insensitive)
	seqlength=$(echo -n "$cleanseq" | wc -c) # Compute total length.	# Get the total length of $cleanseq (containing all sequences in the file)
	echo "# Total length of sequences: "$seqlength""
		
# Determine the type of sequence
	if [[ ! $(echo -n "$cleanseq") =~ [TtKk] ]]; then			# If sequence doesn't contain thymine or lysine it should be ARN
    		echo "# Sequence type: ARN"
    	elif [[ ! $(echo -n "$cleanseq") =~ [UuKk] ]]; then			# If sequence doesn't contain uracil or lysine it should be ADN
    		echo "# Sequence type: ADN"
    	else
    		echo "# Sequence type: PROTEIN"					# If not ADN or ARN, sequence should be from protein.
	fi

# Finally print the content of file using the peek() function.
	peek "$file" "$N"
	echo # add a final newline
done
