class CreateInterventionAccesses < ActiveRecord::Migration[6.0]
  def change
    create_table :intervention_accesses do |t|
      t.belongs_to :intervention, foreign_key: true, null: false, type: :uuid
      t.string :email, null: false
      t.timestamps
    end

    Rake::Task['one_time_use:convert_intervention_invitation_to_intervention_access'].invoke
  end
end
