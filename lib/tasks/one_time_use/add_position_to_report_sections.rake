# frozen_string_literal: true

namespace :one_time_use do
  desc 'Assign correct position to existed report section'
  task assign_position_to_section: :environment do
    class AuxiliarySession < ApplicationRecord
      self.table_name = 'sessions'

      has_many :report_templates
    end

    AuxiliarySession.find_each do |session|
      session.report_templates.find_each do |report_template|
        report_template.sections.each_with_index do |section, index|
          section.update(position: index)
        end
      end
    end
  end
end
