# frozen_string_literal: true

class CreateTeamInvitations < ActiveRecord::Migration[6.0]
  def change
    create_table :team_invitations, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :user_id
      t.uuid :team_id
      t.string :invitation_token
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :team_invitations, :invitation_token, unique: true
    add_index :team_invitations, :accepted_at

    reversible do |direction|
      direction.up do
        execute <<-SQL.squish
          CREATE UNIQUE INDEX unique_not_accepted_team_invitation
            ON team_invitations (user_id, team_id) WHERE accepted_at IS NULL;
        SQL
      end
    end

    reversible do |direction|
      direction.down do
        execute <<-SQL.squish
          DROP INDEX IF EXISTS unique_not_accepted_team_invitation;
        SQL
      end
    end
  end
end
