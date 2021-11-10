# frozen_string_literal: true

workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 4)
threads threads_count, threads_count

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

preload_app!
wait_for_less_busy_worker 0.001
nakayoshi_fork


before_fork do
  GoodJob.shutdown
end

on_worker_boot do
  GoodJob.restart
end

on_worker_shutdown do
  GoodJob.shutdown
end

MAIN_PID = Process.pid

at_exit do
  GoodJob.shutdown if Process.pid == MAIN_PID
end
