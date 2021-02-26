# frozen_string_literal: true

class CreateReportTemplateSectionVariants < ActiveRecord::Migration[6.0]
  def change
    create_table :report_template_section_variants, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :report_template_section_id, null: false
      t.boolean :preview, default: false, null: false
      t.string :formula_match
      t.string :title
      t.text :content

      t.timestamps
    end
    add_index :report_template_section_variants, :report_template_section_id,
              name: 'index_variants_on_section_id'
    add_index :report_template_section_variants, %i[report_template_section_id preview],
              name: 'index_variants_on_preview_and_section_id'
  end
end
