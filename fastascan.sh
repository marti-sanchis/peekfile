#!/usr/bin/env bash


#################### HELP ARGUMENT FOR INFO OF THE FUNCTION ####################

if [[ "$1" == "help" ]]; 
then
echo -e "\n# This function has the form fastascan <arg1> <arg2>, and so it has two optional independent arguments:"
echo "       - arg1. search directory, as an existing absolute or relative path"
echo "       - arg2. number of lines to print for each file, as an integer."
echo -e "\n# Either arg1 or arg2 can be set as the only argument and the other will be set by default."
echo -e "\n# Both arguments can be omitted and will be set by default to current directory and 0 lines."
echo -e "\n# However, when the two arguments are provided, they must follow the order indicated: search directory in arg1 and number of lines in arg2.\n"
exit 0
fi
################################################################################



[[ "$1" =~ ^[0-9] && "$2" =~ .*/.* ]] && { 
	echo WARNING: Arguments are reversed: first argument should be directory and second argument should be number of lines to print. See fastascan help for more info.
	exit 1
}


if [[ -n "$1" ]]; 
then
	if [[ "$1" =~ .*/.* ]]
	then
		! [[ -d "$1" ]] && {
			echo WARNING: Directory provided doesn\'t exist. Try with a correct path. See fastascan help for more info.
			exit 1
			}
		path=$1
		echo -e "\n# Scanning directory "$path" and subdirectories."
		if [[ -n "$2" ]]; 
		then
			! [[ "$2" =~ ^[0-9]+$ ]] && {
				echo WARNING: Number of lines to print should be an integer. See fastascan help for more info.
				exit 1
				}
			N="$2"
			echo -e "\n# Printing the first and last "$N" lines of each fasta file.\n"
		else
			N=0
			echo -e "\n# No lines printed by default.\n"
		fi
	else
		! [[ "$1" =~ ^[0-9]+$ ]] && {
			echo WARNING: Number of lines to print should be an integer. See fastascan help for more info.
			exit 1
			}
		path="$PWD" 
		echo -e "\n# Scanning current directory (by default) and subdirectories."
		N="$1"
		echo -e "\n# Setting the number of printed lines for each fasta to "$N".\n"
	fi
else
	path="$PWD"
	echo -e "\n# Scanning current directory (by default) and subdirectories."
	numlines=0
	echo -e "\n# No lines printed by default.\n"

fi

