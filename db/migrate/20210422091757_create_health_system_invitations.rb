# frozen_string_literal: true

class CreateHealthSystemInvitations < ActiveRecord::Migration[6.0]
  def change
    create_table :health_system_invitations, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id, index: true, foreign_key: true
      t.uuid :health_system_id, index: true, foreign_key: true
      t.string :invitation_token, index: true, unique: true
      t.datetime :accepted_at

      t.timestamps
    end
  end
end
