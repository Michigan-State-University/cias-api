# frozen_string_literal: true

class AddTeamAdminIdToTeams < ActiveRecord::Migration[6.0]
  def change
    add_column :teams, :team_admin_id, :uuid
    add_index :teams, :team_admin_id
  end
end
