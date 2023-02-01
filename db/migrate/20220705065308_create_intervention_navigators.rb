class CreateInterventionNavigators < ActiveRecord::Migration[6.1]
  def change
    create_table :intervention_navigators do |t|
      t.references :user, type: :uuid
      t.references :intervention, type: :uuid

      t.timestamps
    end
  end
end
