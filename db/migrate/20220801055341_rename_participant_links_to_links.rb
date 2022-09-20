class RenameParticipantLinksToLinks < ActiveRecord::Migration[6.1]
  def change
    rename_table :live_chat_participant_links, :live_chat_links
    add_column :live_chat_links, :link_for, :integer, default: 0
  end
end
