class AddPendingSmsAnswerFlagToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :pending_sms_answer, :boolean, default: false
  end
end
