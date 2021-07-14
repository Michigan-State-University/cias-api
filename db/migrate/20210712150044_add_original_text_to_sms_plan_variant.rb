class AddOriginalTextToSmsPlanVariant < ActiveRecord::Migration[6.0]
  def change
    add_column :sms_plan_variants, :original_text, :jsonb
  end
end
