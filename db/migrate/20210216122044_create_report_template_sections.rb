# frozen_string_literal: true

class CreateReportTemplateSections < ActiveRecord::Migration[6.0]
  def change
    create_table :report_template_sections, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :formula
      t.uuid :report_template_id, null: false

      t.timestamps
    end
    add_index :report_template_sections, :report_template_id
  end
end
