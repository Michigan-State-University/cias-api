#!/usr/bin/env bash

GREEN=$(tput setaf 2)
RESET_COLOR=$(tput sgr 0)
CYAN=$(tput setaf 6)

echo ${CYAN}"Deleting databases..."${RESET_COLOR}
rails db:drop:_unsafe
echo ${CYAN}"Recreating databases..."${RESET_COLOR}
rails db:create
echo ${CYAN}"Migrating..."${RESET_COLOR}
rails db:migrate
echo ${CYAN}"Seeding..."${RESET_COLOR}
rails db:seed
echo ${GREEN}"Reset done!"${RESET_COLOR}

