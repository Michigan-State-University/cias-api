# frozen_string_literal: true

class ChangeOrganizationIdToOrganizableIdTuUsers < ActiveRecord::Migration[6.0]
  def change
    rename_column :users, :organization_id, :organizable_id
    add_column :users, :organizable_type, :string
    add_index :users, %i[organizable_id organizable_type]
  end
end
