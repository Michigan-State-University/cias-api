# frozen_string_literal: true

class RelaxSmsLinksForCampaigns < ActiveRecord::Migration[8.1]
  def up
    change_column_null :sms_links, :session_id, true
    change_column_null :sms_links, :sms_plan_id, true
    add_reference :sms_links, :campaign, type: :uuid, null: true, index: false,
                                         foreign_key: { to_table: :predefined_participants_sms_campaigns }
    add_index :sms_links, %i[campaign_id variable], unique: true, where: 'campaign_id IS NOT NULL'

    # Every pre-existing row still satisfies this: `sms_plan_id` was NOT NULL until the line above,
    # and `campaign_id` has just been added as all-NULL.
    add_check_constraint :sms_links, 'num_nonnulls(campaign_id, sms_plan_id) = 1',
                         name: 'sms_links_belong_to_plan_or_campaign'
  end

  def down
    execute <<~SQL.squish
      DELETE FROM sms_links_users
      WHERE sms_link_id IN (SELECT id FROM sms_links WHERE campaign_id IS NOT NULL)
    SQL
    execute 'DELETE FROM sms_links WHERE campaign_id IS NOT NULL'

    remove_check_constraint :sms_links, name: 'sms_links_belong_to_plan_or_campaign', if_exists: true
    remove_index :sms_links, %i[campaign_id variable]
    remove_reference :sms_links, :campaign, foreign_key: { to_table: :predefined_participants_sms_campaigns }
    change_column_null :sms_links, :sms_plan_id, false
    change_column_null :sms_links, :session_id, false
  end
end
