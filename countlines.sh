for file in "$@"; do 
nlines=$(cat "$file" | wc -l)
filename=$(basename "$file")
if [[ $nlines -eq 0 ]]; then echo File named $filename does not contain any line; elif [[ $nlines -eq 1 ]]; then echo File named $filename contains only 1 line ; else echo File named $filename contains '>1' lines; fi; done


