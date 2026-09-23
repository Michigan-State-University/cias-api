# frozen_string_literal: true

class AddTestRunToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :test_run, :boolean, null: false, default: false
    add_column :users, :purge_scheduled_at, :datetime, null: true

    # What the marker actually covers. The token is minted for one intervention, so the purge it
    # eventually authorises must never reach a guest's fills of a different researcher's study.
    # Added here rather than in a later migration because it cannot be backfilled after the fact.
    add_column :users, :test_run_intervention_id, :uuid, null: true

    # Who is accountable for the marker. The marking request is anonymous by construction, so the
    # audit trail has no actor of its own; the minting researcher is the one fact worth keeping.
    add_column :users, :test_run_marked_by_id, :uuid, null: true

    # Only the purge-candidate lookup reads this column, and it always filters on `test_run = true`,
    # so a partial index keeps the index tiny (test runs are a rounding error against all users).
    add_index :users, :test_run, where: 'test_run = true', name: 'index_users_on_test_run'
  end
end
