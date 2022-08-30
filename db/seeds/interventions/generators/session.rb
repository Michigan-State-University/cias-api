# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_sessions(data_handler, session_num)
  default_data = data_handler.new_table_with_default_values('sessions', Session.columns_hash)

  intervention_ids = Intervention.ids

  index = 0
  max_index = intervention_ids.count * session_num

  data = {
    settings: { 'narrator' => { 'voice' => false, 'animation' => true } }.to_json,
    name: 'Pregnancy 1st Trimester',
    schedule: 'after_fill',
    schedule_payload: 1,
    formulas: { 'payload' => '', 'patterns' => [] }.to_json,
    report_templates_count: session_num,
    variable: 's123',
    google_tts_voice_id: 144,
    type: 'Session::Classic',
    estimated_time: 3000,
    cat_mh_language_id: 1,
    cat_mh_time_frame_id: 1,
    cat_mh_population_id: 1
  }
  data = default_data.merge(data)

  intervention_ids.each do |intervention_id|
    position_counter = 0
    session_num.times do
      data[:intervention_id] = intervention_id
      data[:position] = position_counter
      data_handler.store_data(data)
      position_counter += 1

      p "#{index += 1}/#{max_index} sessions created"
    end
  end
  data_handler.save_data_to_db
  p 'Successfully added Sessions to database!'
end

# rubocop:enable Rails/Output
