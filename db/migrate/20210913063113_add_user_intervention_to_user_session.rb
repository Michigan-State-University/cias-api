class AddUserInterventionToUserSession < ActiveRecord::Migration[6.0]
  def change
    add_reference :user_sessions, :user_intervention, type: :uuid, foreign_key: true, optional: true
  end
end
