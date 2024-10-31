nlines=$(cat "$1" | wc -l)
filename=$(basename "$1")
if [[ $nlines -eq 0 ]]; then echo File named $filename does not contain any line; elif [[ $nlines -eq 1 ]]; then echo File named $filename contains only 1 line ; else echo File named $filename contains '>1' lines; fi

