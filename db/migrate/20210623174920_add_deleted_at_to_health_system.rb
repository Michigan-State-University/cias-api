class AddDeletedAtToHealthSystem < ActiveRecord::Migration[6.0]
  def change
    add_column :health_systems, :deleted_at, :datetime
    add_index :health_systems, :deleted_at
  end
end
