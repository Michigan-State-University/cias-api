# frozen_string_literal: true

namespace :one_time_use do
  desc 'Before e-int admin can be assign only for one organization. Thanks this task we assign all existing e-int-admins to organization using new connection'
  task assign_e_int_admins: :environment do
    e_int_admins = User.e_intervention_admins
    e_int_admins.each do |user|
      organization = Organization.find(user.organizable_id)
      organization.e_intervention_admins << user if organization.present?
    end
  end
end
