# frozen_string_literal: true

class RunRakeTaskToSetPositionInSections < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:assign_position_to_section'].invoke
  end
end
