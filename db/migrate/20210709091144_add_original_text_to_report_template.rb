class AddOriginalTextToReportTemplate < ActiveRecord::Migration[6.0]
  def change
    add_column :report_templates, :original_text, :jsonb
  end
end
