class ChangeRevokedAccessDefault < ActiveRecord::Migration[6.0]
  def change
    change_column_default :interventions, :is_access_revoked, from: false, to: true
  end
end
