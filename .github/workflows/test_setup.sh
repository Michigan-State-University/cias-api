#!/usr/bin/env bash

find $1 -name '*_spec.rb' -exec $SHELL -c '
  json_list="["
  for filepath in "$@"; do
    json_list="$json_list\"$filepath\", "
  done
  json_list=${json_list%?}
  json_list=${json_list%?}
  json_list="$json_list]"
  echo $json_list
' {} +

