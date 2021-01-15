# frozen_string_literal: true

class DropSessionInvitationTable < ActiveRecord::Migration[6.0]
  def up
    drop_table :session_invitations
  end

  def down
    create_table 'session_invitations', id: :uuid, default: -> { 'uuid_generate_v4()' }, force: :cascade do |t|
      t.uuid 'session_id', null: false
      t.string 'email'
      t.datetime 'created_at', precision: 6, null: false
      t.datetime 'updated_at', precision: 6, null: false
      t.index %w[session_id email], name: '', unique: true
    end
    add_index :index_session_invitations_on_session_id_and_email, %i[session_id email], unique: true
  end
end
