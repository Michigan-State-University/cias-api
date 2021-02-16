# frozen_string_literal: true

class AddReportTemplatesCountToSessions < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :report_templates_count, :integer
  end
end
