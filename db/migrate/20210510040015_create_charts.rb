# frozen_string_literal: true

class CreateCharts < ActiveRecord::Migration[6.0]
  def change
    create_table :charts, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :name
      t.string :description
      t.string :status, default: 'draft'
      t.jsonb :formula
      t.uuid :dashboard_section_id, index: true, foreign_key: true
      t.datetime :published_at

      t.timestamps
    end
  end
end
