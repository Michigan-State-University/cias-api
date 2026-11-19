# frozen_string_literal: true

class CreatePredefinedParticipantsSmsDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :predefined_participants_sms_deliveries, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.references :campaign, type: :uuid, null: false, index: false,
                              foreign_key: { to_table: :predefined_participants_sms_campaigns }
      t.references :predefined_user_parameter, type: :uuid, null: false,
                                               index: { name: 'index_pp_sms_deliveries_on_predefined_user_parameter_id' },
                                               foreign_key: true
      t.references :message, type: :bigint, null: true,
                             index: { name: 'index_pp_sms_deliveries_on_message_id' },
                             foreign_key: { on_delete: :nullify }
      t.text :body, null: false
      t.string :status, null: false, default: 'pending'
      t.string :error_code
      t.datetime :sent_at
      t.integer :resend_count, null: false, default: 0
      t.datetime :last_resent_at

      t.timestamps
    end

    add_index :predefined_participants_sms_deliveries, %i[campaign_id predefined_user_parameter_id],
              unique: true, name: 'index_pp_sms_deliveries_on_campaign_id_and_participant_id'
  end
end
