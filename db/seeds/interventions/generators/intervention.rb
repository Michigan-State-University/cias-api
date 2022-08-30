# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_interventions(data_handler, intervention_num, sessions_count)
  intervention_statuses = %w[draft published closed archived].freeze
  intervention_names = ['Drugs intervention', 'Smoking intervention', 'Alcohol intervention'].freeze
  intervention_names_directed = ['Husbands', 'Pregnant women', 'Underage teenagers'].freeze

  researcher_ids = User.researchers.ids

  default_data = data_handler.new_table_with_default_values('interventions', Intervention.columns_hash)

  index = 0
  max_index = researcher_ids.count * intervention_num

  data = {
    shared_to: 'anyone',
    google_language_id: 27,
    type: 'Intervention',
    additional_text: 'Eat your veggies!',
    license_type: 'limited',
    is_access_revoked: true,
    sessions_count: sessions_count,
    organization_id: nil
  }
  data = default_data.merge(data)

  researcher_ids.each do |researcher_id|
    intervention_num.times do
      data[:name] = intervention_names.sample + " for #{intervention_names_directed.sample}"
      data[:status] = intervention_statuses.sample
      data[:user_id] = researcher_id
      data_handler.store_data(data)
      p "#{index += 1}/#{max_index} interventions created"
    end
  end
  data_handler.save_data_to_db
  p 'Successfully added Interventions to database!'
end

# rubocop:enable Rails/Output
