# frozen_string_literal: true

class AddShowDashboardButtonToQuestions < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE questions
      SET settings = jsonb_set(settings, '{show_dashboard_button}', 'false', true)
      WHERE type = 'Question::Finish'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE questions
      SET settings = settings - 'show_dashboard_button'
      WHERE type = 'Question::Finish'
    SQL
  end
end
