# frozen_string_literal: true

class CreateLiveChatParticipantLinks < ActiveRecord::Migration[6.1]
  def change
    create_table :live_chat_participant_links, id: :uuid, null: false, default: 'uuid_generate_v4()' do |t|
      t.text :url, null: false
      t.string :display_name, default: '', null: false
      t.uuid :navigator_setup_id, null: false
      t.timestamps
    end

    add_foreign_key :live_chat_participant_links, :live_chat_navigator_setups, column: :navigator_setup_id, index: true
  end
end
