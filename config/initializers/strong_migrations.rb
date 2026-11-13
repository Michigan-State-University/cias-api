# frozen_string_literal: true

# Mark existing migrations as safe. This is the newest migration in the repo when
# the gem was added, so migrations created after it on unmerged branches are still
# checked (the gem's generator would use the install time instead). Grouped like the
# version in db/schema.rb.
StrongMigrations.start_after = 2026_09_22_090000 # rubocop:disable Style/NumericLiterals

# Set timeouts for migrations. They apply wherever migrations run: locally, the
# Dokku release phase and the ECS migrate task.
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Analyze tables after indexes are added
# Outdated statistics can sometimes hurt performance
StrongMigrations.auto_analyze = true

# Set the version of the production database
# so the right checks are run in development
StrongMigrations.target_version = 13

# Add custom checks
# StrongMigrations.add_check do |method, args|
#   if method == :add_index && args[0].to_s == "users"
#     stop! "No more indexes on the users table"
#   end
# end

# Remove invalid indexes when rerunning migrations
# StrongMigrations.remove_invalid_indexes = true

# Make some operations safe by default
# See https://github.com/ankane/strong_migrations#safe-by-default
# StrongMigrations.safe_by_default = true
