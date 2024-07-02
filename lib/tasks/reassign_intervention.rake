# frozen_string_literal: true

namespace :intervention do
  desc 'Change ownership of the intervention by passing intervention_id and email belongs to the new owner'
  task :change_ownership, %i[intervention email] => :environment do |_t, args|
    intervention = Intervention.find(args.intervention)
    user = User.find_by!(email: args.email)

    intervention.update!(user: user)
    puts 'Everything was processed correctly, pleas check on CIAS app if you see expected result'
  end
end
