# frozen_string_literal: true

class CreateGeneratedReports < ActiveRecord::Migration[6.0]
  def change
    create_table :generated_reports, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :name
      t.uuid :report_template_id
      t.uuid :user_session_id
      t.string :report_for, default: 'third_party', null: false
      t.boolean :shown_for_participant, default: false

      t.timestamps
    end
    add_index :generated_reports, :report_template_id
    add_index :generated_reports, :user_session_id
    add_index :generated_reports, :shown_for_participant
    add_index :generated_reports, :report_for
  end
end
