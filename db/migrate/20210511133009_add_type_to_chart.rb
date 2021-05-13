# frozen_string_literal: true

class AddTypeToChart < ActiveRecord::Migration[6.0]
  def change
    add_column :charts, :type, :string
  end
end
