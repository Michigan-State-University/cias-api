# frozen_string_literal: true

class AddIndexToOrganization < ActiveRecord::Migration[6.0]
  def change
    add_index :organizations, :name
  end
end
