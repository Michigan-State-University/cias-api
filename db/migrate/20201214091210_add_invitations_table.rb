# frozen_string_literal: true

class AddInvitationsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :invitations do |t|
      t.string :email
      t.uuid :invitable_id
      t.string :invitable_type
      t.timestamps
    end
    add_index :invitations, %i[invitable_type invitable_id email], unique: true
  end
end
