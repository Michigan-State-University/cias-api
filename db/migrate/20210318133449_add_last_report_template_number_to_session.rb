class AddLastReportTemplateNumberToSession < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :last_report_template_number, :integer, default: 0
  end
end
