class CreateTableToTrackEventsInSmsCampaign < ActiveRecord::Migration[7.2]
  def change
    create_table :sms_campaign_events do |t|
      t.jsonb :event_data, null: false, default: {}
      t.string :event_type, null: false
      t.references :user_session, null: true, foreign_key: true, type: :uuid
      t.timestamps
    end
  end
end
