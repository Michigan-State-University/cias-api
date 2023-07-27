class UpdateSettingsInExisitingNumberQuestions < ActiveRecord::Migration[6.1]
  def up
    p '-- set default value for all existing question(except TlfbConfig and FinishScreen) for start_autofinish_timer flag '
    query = <<~SQL.squish
      UPDATE questions
      SET settings = jsonb_set(jsonb_set(settings, '{min_length}', 'null', true), '{max_length}', 'null', true)
      WHERE type IN ('Question::Number')
    SQL
    ActiveRecord::Base.connection.exec_query(query)
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
