class CreateDownloadedReports < ActiveRecord::Migration[6.1]
  def change
    create_table :downloaded_reports, id: :uuid, null: false, default: 'uuid_generate_v4()' do |t|
      t.belongs_to :user, null: false, foreign_key: true, type: :uuid
      t.belongs_to :generated_report, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
    add_index(:downloaded_reports, [:user_id, :generated_report_id])
  end
end
