# frozen_string_literal: true

class AddColumnsToStoreInformationAboutAutofinish < ActiveRecord::Migration[6.1]
  def change
   change_table(:sessions, bulk: true) do |t|
      t.boolean(:autofinish_enabled, default: true, null: false)
      t.integer(:autofinish_delay, null: false, default: 24)
    end
  end
end
