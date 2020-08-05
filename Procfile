web: RUBYOPT=--jit bundle exec puma -C config/puma.rb
worker: RUBYOPT=--jit bundle exec sidekiq -C config/sidekiq.yml
release: rails db:migrate
