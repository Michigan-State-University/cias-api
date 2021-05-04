# frozen_string_literal: true

class AddOrganizationIdToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :organization_id, :uuid
    add_index :users, :organization_id
  end
end
