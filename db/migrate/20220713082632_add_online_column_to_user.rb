# frozen_string_literal: true

class AddOnlineColumnToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :online, :boolean, default: false, null: false
  end
end
