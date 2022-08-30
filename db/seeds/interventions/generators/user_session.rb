# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_user_sessions(data_handler, max_per_user_inter)
  default_data = data_handler.new_table_with_default_values('user_sessions', UserSession.columns_hash)

  user_interventions = UserIntervention.all
  participants_ids = User.participants.ids

  user_session_created_count = [max_per_user_inter, user_interventions.first&.intervention&.sessions&.count].min
  index = 0
  max_index = participants_ids.count * user_interventions.count * user_session_created_count

  data = {
    type: 'UserSession::Classic',
    name_audio_id: nil,
    health_clinic_id: nil
  }
  data = default_data.merge(data)

  participants_ids.each do |participant_id|
    user_interventions.each do |user_intervention|
      user_intervention.intervention.sessions.limit(max_per_user_inter).each do |session|
        data[:user_id] = participant_id
        data[:session_id] = session.id
        data[:user_intervention_id] = user_intervention.id
        data_handler.store_data(data)

        p "#{index += 1}/#{max_index} user sessions created"
      end
    end
  end
  data_handler.save_data_to_db
  p 'Successfully added UserSessions to database!'
end

# rubocop:enable Rails/Output
