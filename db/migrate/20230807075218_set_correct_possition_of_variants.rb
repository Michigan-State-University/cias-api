# frozen_string_literal: true

class SetCorrectPossitionOfVariants < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:assign_position_to_report_template_variants'].invoke
  end
end
