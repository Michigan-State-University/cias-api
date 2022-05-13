class CreateUserIntervention < ActiveRecord::Migration[6.0]
  def change
    create_table :user_interventions, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.belongs_to :user, type: :uuid
      t.belongs_to :intervention, type: :uuid
      t.belongs_to :health_clinic, type: :uuid, optional: true
      t.integer :completed_sessions, default: 0, null: false
      t.string :status, default: "ready_to_start"
      t.datetime :finished_at

      t.timestamps
    end
  end
end
