class SetStartAutoFinishTimerFlagForExistedQuestions < ActiveRecord::Migration[6.1]
  def up
    p '-- set default value for all existing question(except TlfbConfig and FinishScreen) for start_autofinish_timer flag '
    query = <<~SQL.squish
      UPDATE questions
      SET settings = jsonb_set(settings, '{start_autofinish_timer}', 'false', true)
      WHERE type NOT IN ('Question::TlfbConfig', 'Question::Finish')
    SQL
    ActiveRecord::Base.connection.exec_query(query)
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
