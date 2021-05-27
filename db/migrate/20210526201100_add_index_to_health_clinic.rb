# frozen_string_literal: true

class AddIndexToHealthClinic < ActiveRecord::Migration[6.0]
  def change
    add_index :health_clinics, :name
  end
end
