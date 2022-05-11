# frozen_string_literal: true

class AddPositionToSmsVariants < ActiveRecord::Migration[6.1]
  def change
    add_column :sms_plan_variants, :position, :integer, default: 0, null: false
  end
end
