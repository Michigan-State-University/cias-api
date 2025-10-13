class AddHelpfullToFieldToHandleRepetionsInSmsCampaign < ActiveRecord::Migration[7.2]
  def change
    add_reference :messages, :question, foreign_key: true, type: :uuid
    add_column :user_sessions, :max_repetitions_reached_at, :datetime
  end
end
