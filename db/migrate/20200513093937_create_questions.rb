# frozen_string_literal: true

class CreateQuestions < ActiveRecord::Migration[6.0]
  def change
    create_table :questions, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :type, null: false
      t.uuid :question_group_id, null: false
      t.jsonb :settings
      t.integer :position, null: false, default: 0
      t.string :title, null: false, default: ''
      t.string :subtitle
      t.jsonb :narrator
      t.string :video_url
      t.jsonb :formula
      t.jsonb :body

      t.timestamps
    end

    add_index :questions, :type
    add_index :questions, :question_group_id
    add_index :questions, :title
    add_index :questions, %i[type title], using: :gin
    add_index :questions, %i[type question_group_id title], using: :gin

    add_foreign_key :questions, :question_groups
  end
end
