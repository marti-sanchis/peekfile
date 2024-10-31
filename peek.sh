if [[ -z "$2" ]]; then num_lines=3; else num_lines=$2; fi
#head -n $num_lines $1; echo ...; tail -n $num_lines $1

total_lines=$(wc -l < "$1")

if [[ $total_lines -le $((2 * num_lines)) ]]; then cat "$1";
else
  echo "Warning: Showing only the first $num_lines and last $num_lines lines of a larger file."
  head -n "$num_lines" "$1"
  echo "..."
  tail -n "$num_lines" "$1"; fi

