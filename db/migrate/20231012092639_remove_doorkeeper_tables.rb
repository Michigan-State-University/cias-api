class RemoveDoorkeeperTables < ActiveRecord::Migration[6.1]
  def up
    drop_table :oauth_access_grants
    drop_table :oauth_access_tokens
    drop_table :oauth_applications
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
