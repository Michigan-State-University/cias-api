class ClearCacheForSimpleInterventionsSerializer < ActiveRecord::Migration[6.1]
  def up
    Rails.cache.clear(namespace: 'simple-intervention-serializer')
  end

  def down
    raise(ActiveRecord::IrreversibleMigration)
  end
end
