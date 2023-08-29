class AssignTeamAdminRoleToTeamAdmin < ActiveRecord::Migration[6.1]
  def up
    User.joins(:admins_teams).where("ARRAY['team_admin']::varchar[] <> roles").find_each do |user|
      user.roles << 'team_admin'
      user.save!
    end
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
