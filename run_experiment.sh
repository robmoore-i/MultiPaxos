#!/bin/bash

# USAGE: ./run_experiment.sh FILENAME

if [[ $# -eq 0 ]]; then
  echo ""
  echo "    USAGE: ./run_experiment.sh FILENAME"
  echo ""
  exit 1
fi

# Makes clean, compiles, runs and saves output to the given FILENAME in the format:

# [csv config-headers]
# [csv config-values]
# ticked updates:
# 0
# ...
# [time.0] seconds

(make clean && make run) > $1 # Build the file
sed -i -e 1,4d $1             # Delete the build logging lines (first 4 lines)
sed -i '$ d' $1               # Delete the last line of dashes made by System.Halt

exit 0
