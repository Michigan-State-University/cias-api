class CreateLiveChatSummoningUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :live_chat_summoning_users, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.belongs_to :user, null: false, foreign_key: true, type: :uuid
      t.belongs_to :intervention, null: false, foreign_key: true, type: :uuid
      t.timestamp :unlock_next_call_out_time
      t.boolean :participant_handled, default: false

      t.timestamps
    end
  end
end
