class CreateDays < ActiveRecord::Migration[6.1]
  def change
    create_table :days do |t|
      t.date :exact_date, null: false
      t.references :user_session, null: false, foreign_key: true, type: :uuid
      t.references :question_group, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
