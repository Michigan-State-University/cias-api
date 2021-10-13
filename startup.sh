#!/bin/bash
# turn on bash's job control
set -m

# print env var for checking if container pass in the correct values
env

# create db and schema
rails db:create
rails db:migrate
rake db:seed:prod

# Run sidekiq
bundle exec sidekiq &
# Wait for sidekiq to start
sleep 5
# Run rails server
rails s -e production

echo
