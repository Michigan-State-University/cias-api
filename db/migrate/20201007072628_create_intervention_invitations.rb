# frozen_string_literal: true

class CreateInterventionInvitations < ActiveRecord::Migration[6.0]
  def change
    create_table :intervention_invitations, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :intervention_id, null: false
      t.string :email

      t.timestamps
    end

    add_index :intervention_invitations, %i[intervention_id email], unique: true

    add_foreign_key :intervention_invitations, :interventions
  end
end
