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

arg_err(){
	exit_code="$1"
	[[ "$exit_code" -eq 10 ]] && {
		echo "\nERROR: arg1 is not an existing directory and/or arg2 is not an integer." 
		echo "++ Use fastascan help for more info.\n"
		exit 10
	} || [[ "$exit_code" -eq 11 ]] && {
		echo "\nERROR: arg1 is not an existing directory or a correct number of lines (integer)." 
		echo "++ Use fastascan help for more info.\n"
		exit 11
	} || [[ "$exit_code" -eq 12 ]] && {
		echo "\nERROR: Arguments are reversed. First argument should be directory and second argument should be number of lines to print." 
		echo "++ Use fastascan help for more info.\n"
		exit 12
	}
}
#################################################   CONTROL FOR THE ARGUMENTS   #################################################
#------------------------------------------   Functions for setting directory and N  --------------------------------------------

set_path(){
	[[ $1 != "$PWD" ]] && {
		path="$1"
		echo "\nSETTINGS:"
		echo "# Scanning directory "$path" and subdirectories."
	} || {
		path="$PWD"
		echo "\nSETTINGS:"
		echo "# Scanning current directory (by default) and subdirectories."
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
#--------------------------------------------   Setting directory and N correctly   ---------------------------------------------
if [[ -n "$1" && -n "$2"  ]]
then
	[[ "$1" =~ ^[0-9] && "$2" =~ .*/.* ]] && { 
		arg_err 12
	}
	
	[[ -d "$1" && "$2" =~ ^[0-9]+$ ]] && {
		set_path "$1"
		set_N "$2"
	} || {
		arg_err 10
	}
	
elif [[ -n "$1" && -z "$2" ]]
then
	[[ -d "$1" ]] && {
		set_path "$1"
		set_N 0
	} || [[ "$1" =~ ^[0-9]+$ ]] && {
		set_path "$PWD"
		set_N "$1"
	} || {
		arg_err 11
	}
else
	set_path "$PWD"
	set_N 0
fi

####################################   SCANNING DIRECTORY AND SUBDIRECTORIES FOR FA/FASTAS   ####################################
#------------------------------------------------   FASTA count and unique   ----------------------------------------------------

fastacount=$(find . -type f -name "*.fa" -or -name "*.fasta" | wc -l)
uniqID_total=$(cat $(find . -type f -name "*.fa" -or -name "*.fasta") | awk '/>/{print $1}' | sort | uniq | wc -l)

echo "SCAN RESULTS:"
echo "# There are "$fastacount" FASTA files in the directory provided and its subdirectories."
echo "# These files cointain a total of "$uniqID_total" different sequence IDs.\n"


#-----------------------------------------------------   FASTA header   ---------------------------------------------------------

find . -type f -name "*.fa" -or -name "*.fasta" | while read i
do
	echo $i
done

