class RemoveBodyFromSession < ActiveRecord::Migration[6.0]
  def change
    remove_column :sessions, :body, :jsonb
    change_column :sessions, :report_templates_count, :integer, :default => 0, null: false
  end
end
