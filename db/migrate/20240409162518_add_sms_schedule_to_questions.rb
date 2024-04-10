class AddSmsScheduleToQuestions < ActiveRecord::Migration[6.1]
  def change
    add_column :questions, :sms_schedule, :jsonb
  end
end
