# frozen_string_literal: true

class AddTeamIdToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :team_id, :uuid

    add_index :users, :team_id
  end
end
