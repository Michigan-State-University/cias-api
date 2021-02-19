# frozen_string_literal: true

class AddPreviewSessionIdToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :preview_session_id, :uuid
    add_index :users, :preview_session_id
  end
end
