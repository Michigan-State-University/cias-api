class ClearInterventionCache < ActiveRecord::Migration[6.1]
  def up
    Rails.cache.clear(namespace: 'intervention-serializer')
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
