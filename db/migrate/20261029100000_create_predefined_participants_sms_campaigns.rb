# frozen_string_literal: true

class CreatePredefinedParticipantsSmsCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :predefined_participants_sms_campaigns, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.references :intervention, type: :uuid, null: false, index: false, foreign_key: true
      t.references :author, type: :uuid, null: true,
                            index: { name: 'index_pp_sms_campaigns_on_author_id' },
                            foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :parent_campaign, type: :uuid, null: true, index: false,
                                     foreign_key: { to_table: :predefined_participants_sms_campaigns }
      t.string :kind, null: false
      t.string :status, null: false, default: 'scheduled'
      t.text :body, null: false
      t.datetime :scheduled_at, null: false
      t.integer :days_after
      t.datetime :sent_at
      t.integer :recipients_count
      t.integer :accepted_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0

      t.timestamps
    end

    add_index :predefined_participants_sms_campaigns, %i[intervention_id created_at],
              name: 'index_pp_sms_campaigns_on_intervention_id_and_created_at'
    add_index :predefined_participants_sms_campaigns, %i[status scheduled_at],
              name: 'index_pp_sms_campaigns_on_status_and_scheduled_at'
    add_index :predefined_participants_sms_campaigns, :parent_campaign_id,
              unique: true, where: 'parent_campaign_id IS NOT NULL',
              name: 'index_pp_sms_campaigns_on_parent_campaign_id'
    add_index :predefined_participants_sms_campaigns, %i[intervention_id kind],
              unique: true,
              where: "status IN ('scheduled', 'sending') AND kind <> 'scheduled_reminder'",
              name: 'index_pp_sms_campaigns_one_in_flight_per_kind'
  end
end
