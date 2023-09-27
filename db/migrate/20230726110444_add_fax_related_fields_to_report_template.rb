class AddFaxRelatedFieldsToReportTemplate < ActiveRecord::Migration[6.1]
  def change
    change_table :report_templates do |t|
      t.boolean :has_cover_letter, null: false, default: false
      t.string :cover_letter_logo_type, null: false, default: :report_logo
      t.string :cover_letter_description
      t.string :cover_letter_sender
    end
  end
end
