class RenameIsCloningToIsHidden < ActiveRecord::Migration[6.1]
  def change
    rename_column :interventions, :is_cloning, :is_hidden
  end
end
