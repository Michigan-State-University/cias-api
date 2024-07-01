class AddSmsRemidersToQuestions < ActiveRecord::Migration[6.1]
  def change
    add_column :questions, :sms_reminders, :jsonb, default: {}
  end
end
