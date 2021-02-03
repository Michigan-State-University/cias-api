# frozen_string_literal: true

class AddUniqueIndexToTheTeamsName < ActiveRecord::Migration[6.0]
  def change
    add_index :teams, :name, unique: true
  end
end
