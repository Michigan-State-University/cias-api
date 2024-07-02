class AddSmsScheduleToQuestionGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :question_groups, :sms_schedule, :jsonb
  end
end
