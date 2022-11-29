# frozen_string_literal: true

class AddFlagForMultipleSessionsToSession < ActiveRecord::Migration[6.1]
  def change
    add_column :sessions, :multiple_fill, :boolean, null: false, default: false
  end
end
