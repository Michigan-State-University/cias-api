# frozen_string_literal: true

namespace :one_time_use do
  desc 'converts old intervention invitations to new intervention accesses'
  task convert_intervention_invitation_to_intervention_access: :environment do
    Invitation.where(invitable_type: 'Intervention').all.each do |inv|
      intervention = Intervention.find(inv.invitable_id)
      user = intervention.user
      InterventionAccess.create!(email: user.email, intervention: intervention)
    end
  end
end
