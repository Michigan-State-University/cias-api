# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_report_template(data_handler)
  default_data = data_handler.new_table_with_default_values('report_templates', ReportTemplate.columns_hash)

  session_ids = Session.ids

  index = 0
  max_index = session_ids.count

  data = {
    report_for: 'participant',
    summary: 'Good job!'
  }
  data = default_data.merge(data)

  position = ReportTemplate.count
  session_ids.each do |session_id|
    next unless ReportTemplate.where('name = ? AND session_id = ?', "Report #{position}", session_id).empty?

    data[:name] = "Report #{position}"
    data[:session_id] = session_id
    data_handler.store_data(data)
    position += 1

    p "#{index += 1}/#{max_index} report templates created"
  end
  data_handler.save_data_to_db
  p 'Successfully added ReportTemplates to database!'
end

# rubocop:enable Rails/Output
