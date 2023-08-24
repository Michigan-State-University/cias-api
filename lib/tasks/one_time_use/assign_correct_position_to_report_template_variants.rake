# frozen_string_literal: true

namespace :one_time_use do
  desc 'Assign correct position to existing report template variants'
  task assign_position_to_report_template_variants: :environment do
    ReportTemplate::Section.find_each do |section|
      section.variants.find_each.with_index do |variant, index|
        variant.update!(position: index)
      end
    end
  end
end
