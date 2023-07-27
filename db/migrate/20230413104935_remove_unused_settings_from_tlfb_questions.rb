class RemoveUnusedSettingsFromTlfbQuestions < ActiveRecord::Migration[6.1]
  def up
    p '-- remove unused settings for all kind of TLFB questions'
    query = <<~SQL.squish
      UPDATE questions
      SET settings = CASE
                      WHEN type = 'Question::TlfbConfig' THEN '{}'::jsonb
                      ELSE '{"start_autofinish_timer": false}'::jsonb
                    END
      WHERE type IN ('Question::TlfbEvents', 'Question::TlfbQuestion', 'Question::TlfbConfig')
    SQL
    ActiveRecord::Base.connection.exec_query(query)
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
