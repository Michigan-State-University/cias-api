# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_user_interventions(data_handler, user_inter_num)
  default_data = data_handler.new_table_with_default_values('user_interventions', UserIntervention.columns_hash)

  intervention_ids = Intervention.ids

  index = 0
  max_index = intervention_ids.count * user_inter_num

  data = {
    health_clinic_id: nil,
    completed_sessions: user_inter_num,
    status: 'completed'
  }
  data = default_data.merge(data)

  participants_ids = User.participants.ids
  intervention_ids.each do |intervention_id|
    participants_ids.each do |participant_id|
      data[:user_id] = participant_id
      data[:intervention_id] = intervention_id
      data_handler.store_data(data)
      p "#{index += 1}/#{max_index} user interventions created"
    end
  end
  data_handler.save_data_to_db
  p 'Successfully added UserIntervention to database!'
end

# rubocop:enable Rails/Output
