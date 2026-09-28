# frozen_string_literal: true

class AddTestRunToUsers < ActiveRecord::Migration[7.2]
  def change
    change_table :users, bulk: true do |t|
      t.boolean :test_run, null: false, default: false
      t.datetime :purge_scheduled_at, null: true
      t.uuid :test_run_intervention_id, null: true
      t.uuid :test_run_marked_by_id, null: true
    end

    add_index :users, :test_run, where: 'test_run = true', name: 'index_users_on_test_run'
  end
end
