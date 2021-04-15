# frozen_string_literal: true

class AddVariableToSession < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :variable, :string
  end
end
