# frozen_string_literal: true

class EnableDashboardButtonForModuleInterventionFinishScreens < ActiveRecord::Migration[7.2]
  def up
    query = <<~SQL.squish
      UPDATE questions
      SET
        settings = jsonb_set(COALESCE(questions.settings, '{}'::jsonb), '{show_dashboard_button}', 'true'::jsonb, true),
        updated_at = NOW()
      FROM question_groups, sessions, interventions
      WHERE questions.question_group_id = question_groups.id
        AND question_groups.session_id = sessions.id
        AND sessions.intervention_id = interventions.id
        AND questions.type = 'Question::Finish'
        AND interventions.type IN ('Intervention::FixedOrder', 'Intervention::FlexibleOrder')
    SQL
    ActiveRecord::Base.connection.exec_query(query)
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
