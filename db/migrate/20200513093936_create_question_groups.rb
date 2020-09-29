# frozen_string_literal: true

class CreateQuestionGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :question_groups, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :intervention_id, null: false
      t.string :title, null: false
      t.boolean :default, null: false, default: false
      t.bigint :position, null: false, default: 0

      t.timestamps
    end

    add_index :question_groups, :intervention_id
    add_index :question_groups, :title
    add_index :question_groups, :default
    add_index :question_groups, %i[intervention_id title], using: :gin

    add_foreign_key :question_groups, :interventions
  end
end
