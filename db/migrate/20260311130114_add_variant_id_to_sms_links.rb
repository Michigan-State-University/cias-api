# frozen_string_literal: true

class AddVariantIdToSmsLinks < ActiveRecord::Migration[7.2]
  def change
    add_reference :sms_links, :variant, type: :uuid, null: true, foreign_key: { to_table: :sms_plan_variants }, index: true

    # Replace the existing full unique index with a partial one scoped to no-formula links (variant_id IS NULL)
    remove_index :sms_links, name: 'index_sms_links_on_sms_plan_id_and_variable'
    add_index :sms_links, %i[sms_plan_id variable], unique: true,
              where: 'variant_id IS NULL',
              name: 'index_sms_links_on_sms_plan_id_and_variable'

    # Partial unique index for formula (variant-scoped) links
    add_index :sms_links, %i[variant_id variable], unique: true,
              where: 'variant_id IS NOT NULL',
              name: 'index_sms_links_on_variant_id_and_variable'
  end
end
