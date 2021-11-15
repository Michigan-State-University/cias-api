web: RUBYOPT=--jit bundle exec puma -C config/puma.rb
worker: RUBYOPT=--jit bundle exec good_job
release: rails db:migrate
