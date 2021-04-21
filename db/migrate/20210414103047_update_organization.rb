class UpdateOrganization < ActiveRecord::Migration[6.0]
  def change
    change_column :organizations, :name, :string, null: false
  end
end
