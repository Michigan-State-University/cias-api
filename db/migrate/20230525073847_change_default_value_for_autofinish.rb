class ChangeDefaultValueForAutofinish < ActiveRecord::Migration[6.1]

  class AuxiliarySession < ApplicationRecord
    self.table_name = 'sessions'
  end

  def change
    change_column_default(:sessions, :autofinish_delay, from: 24, to: 1_440)
    change_column_default(:sessions, :autofinish_enabled, from: true, to: false)
    AuxiliarySession.update_all(autofinish_delay: 1_440, autofinish_enabled: false)
  end
end
