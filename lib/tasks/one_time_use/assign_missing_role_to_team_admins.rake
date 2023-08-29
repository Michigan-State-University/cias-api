# frozen_string_literal: true

namespace :one_time_use do
  desc 'Some team admins don\'t have team admin role assigned to their account'
  task assign_position_to_sms_variants: :environment do
    SmsPlan.find_each do |plan|
      plan.variants.find_each.with_index do |variant, index|
        variant.update!(position: index)
      end
    end
  end
end
