# frozen_string_literal: true

class CreateTableGeneratedReportsThirdPartyUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :generated_reports_third_party_users, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.uuid :generated_report_id, index: { name: 'index_reports_third_party_users_on_reports_id' }, foreign_key: true
      t.uuid :third_party_id, index: { name: 'index_third_party_users_reports_on_reports_id' }, foreign_key: true

      t.timestamps
    end
  end
end
