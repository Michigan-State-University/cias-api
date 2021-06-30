# frozen_string_literal: true

class AddDeletedAtToHealthClinic < ActiveRecord::Migration[6.0]
  def change
    add_column :health_clinics, :deleted_at, :datetime
    add_index :health_clinics, :deleted_at
  end
end
