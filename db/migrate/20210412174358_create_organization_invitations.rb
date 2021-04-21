class CreateOrganizationInvitations < ActiveRecord::Migration[6.0]
  def change
    create_table :organization_invitations, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id, index: true, foreign_key: true
      t.uuid :organization_id, index: true, foreign_key: true
      t.string :invitation_token, index: true, unique: true
      t.datetime :accepted_at

      t.timestamps
    end
  end
end
