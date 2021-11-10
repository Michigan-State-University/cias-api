# Keeps job records in your database even after jobs are completed.
GoodJob.preserve_job_records = true

GoodJob::Engine.middleware.use(Rack::Auth::Basic) do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(ENV['GOOD_JOB_USERNAME'], username) &&
    ActiveSupport::SecurityUtils.secure_compare(ENV['GOOD_JOB_PASSWORD'], password)
end
