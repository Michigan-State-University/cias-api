# frozen_string_literal: true

class CreateReportTemplates < ActiveRecord::Migration[6.0]
  def change
    create_table :report_templates, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :name, null: false
      t.string :report_for, default: 'third_party', null: false
      t.uuid :session_id
      t.text :summary

      t.timestamps
    end

    add_index :report_templates, :session_id
    add_index :report_templates, :report_for
    add_index :report_templates, %i[session_id name], unique: true
  end
end
