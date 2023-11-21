#!/bin/bash

line="$(echo "$1" | head -1)" # get first line
line="${line%%\#*}" # remove comment
line="$(echo "$line" | awk '{gsub(/^[[:space:]]+|[[:space:]]+$/,"")}1')" # trim

statuses="$(echo "$line" | awk '{gsub(/[^[:alpha:]]/," ")}1' | xargs | jq -Rc 'split(" ")')"

if [ -z "$statuses" ]; then
  echo '[]'
else
  invalid_num="$(echo "$statuses" | jq 'map(select(.!="added" and .!="modified" and .!="renamed" and .!="removed"))|length')"
  if [ "$invalid_num" != 0 ]; then
    exit 1
  else
    echo "$statuses"
  fi
fi
