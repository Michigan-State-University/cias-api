class AddThirdPartyIdToGeneratedReports < ActiveRecord::Migration[6.0]
  def change
    add_column :generated_reports, :third_party_id, :uuid
    add_index :generated_reports, :third_party_id
  end
end
