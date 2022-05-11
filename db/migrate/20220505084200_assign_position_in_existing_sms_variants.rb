# frozen_string_literal: true

class AssignPositionInExistingSmsVariants < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:assign_position_to_sms_variants'].invoke
  end
end
