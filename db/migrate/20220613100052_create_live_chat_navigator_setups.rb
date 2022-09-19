# frozen_string_literal: true

class CreateLiveChatNavigatorSetups < ActiveRecord::Migration[6.1]
  def change
    create_table :live_chat_navigator_setups, id: :uuid, null: false, default: 'uuid_generate_v4()' do |t|
      t.string :no_navigator_available_message, null: false, default: ''
      t.string :contact_email, null: false, default: ''
      t.string :notify_by, null: true
      t.uuid :intervention_id
      t.timestamps
    end

    add_foreign_key :live_chat_navigator_setups, :interventions, column: :intervention_id, index: true
  end
end
