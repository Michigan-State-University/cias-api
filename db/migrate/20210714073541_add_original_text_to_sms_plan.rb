class AddOriginalTextToSmsPlan < ActiveRecord::Migration[6.0]
  def change
    add_column :sms_plans, :original_text, :jsonb
  end
end
