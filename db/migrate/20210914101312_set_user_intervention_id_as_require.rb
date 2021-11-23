class SetUserInterventionIdAsRequire < ActiveRecord::Migration[6.0]
  Rake::Task['user_session:assign_user_session_to_user_intervention'].invoke

  def change
    change_column_null :user_sessions, :user_intervention_id, false
  end
end
