#!/bin/bash

function convert() {
  local input=$1
  local output=$2
  # do your thing here
  echo "ffmpeg -i $input $output"
  #ffmpeg -i $input $output
  local return_code=$?
  if (( $return_code > 0 )) ; then
    echo "ffmpeg return_code = $return_code on converion of $input to $output"
    exit $return_code
  fi
}

if (( $# < 2 )); then
  echo "Error: missing arguments"
  exit 1
fi

#echo "\$1=$1"
#echo "\$2=$2"

pwd
for fullfile in *
do
  #echo "start of loop"
  filename_ext=$(basename -- $fullfile) ; echo "filename_ext=$filename_ext"
  filename="'${filename_ext%.*}'" ; echo "filename=$filename"
  extension="${filename_ext##*.}" ; echo "extension=$extension"
  if [ $extension == $1 ]; then
    #echo "convert $filename.$1 $filename.$2"
    convert "$filename.$1" "$filename.$2"
  fi
  #echo "end of loop"
done
