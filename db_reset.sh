#!/usr/bin/env bash

GREEN=$(tput setaf 2)
RESET_COLOR=$(tput sgr 0)
CYAN=$(tput setaf 6)

echo ${CYAN}"Deleting databases..."${RESET_COLOR}
rails db:drop:_unsafe
echo ${CYAN}"Recreating databases..."${RESET_COLOR}
rails db:setup
echo ${CYAN}"Fetching google languages..."${RESET_COLOR}
rake google_languages:fetch
echo ${GREEN}"Reset done!"${RESET_COLOR}

