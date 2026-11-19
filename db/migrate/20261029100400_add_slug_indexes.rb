# frozen_string_literal: true

# Both slugs are credentials: sms_links_users.slug resolves the unauthenticated /link/<slug>
# and predefined_user_parameters.slug the unauthenticated /usr/<slug>, so a duplicate hands
# one participant another participant's session. Only a model validation guarded them before,
# and on create that validation ran against a nil slug.
#
# A duplicate is refused here rather than rewritten: every slug has already been sent to a
# participant inside a link, so rewriting one silently breaks a message already delivered.
# Collisions are not expected; if one exists, it is a data incident for a person to resolve.
class AddSlugIndexes < ActiveRecord::Migration[8.1]
  TABLES = %w[sms_links_users predefined_user_parameters].freeze

  def up
    TABLES.each { |table| assert_no_duplicate_slugs!(table) }
    execute "LOCK TABLE #{TABLES.join(', ')} IN SHARE ROW EXCLUSIVE MODE"
    TABLES.each { |table| add_index table, :slug, unique: true }
  end

  def down
    TABLES.each { |table| remove_index table, :slug }
  end

  private

  def assert_no_duplicate_slugs!(table)
    duplicates = select_values(<<~SQL.squish)
      SELECT slug FROM #{table} GROUP BY slug HAVING count(*) > 1 ORDER BY slug LIMIT 20
    SQL
    return if duplicates.empty?

    raise ActiveRecord::MigrationError,
          "#{table}: #{duplicates.size} duplicate slug(s) block the unique index: #{duplicates.join(', ')}. " \
          'Rewriting one invalidates a link already sent to a participant, so resolve them deliberately.'
  end
end
