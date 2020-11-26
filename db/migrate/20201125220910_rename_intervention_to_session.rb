# frozen_string_literal: true

class RenameInterventionToSession < ActiveRecord::Migration[6.0]
  def change
    rename_table :interventions, :sessions
    rename_column :question_groups, :intervention_id, :session_id
    rename_table :user_interventions, :user_sessions
    rename_column :user_sessions, :intervention_id, :session_id
    rename_table :intervention_invitations, :session_invitations
    rename_column :session_invitations, :intervention_id, :session_id
  end
end
