# frozen_string_literal: true

class AddInterventionRelationToConversation < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_conversations, :intervention_id, :uuid, null: false
    add_foreign_key :live_chat_conversations, :interventions, column: :intervention_id, index: true
  end
end
