# frozen_string_literal: true

class RemoveNameAndUnitFromSubstances < ActiveRecord::Migration[6.1]
  def change
    remove_column :substances, :name
    remove_column :substances, :unit
  end
end
