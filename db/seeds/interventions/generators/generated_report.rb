# frozen_string_literal: true

# rubocop:disable Rails/Output
def create_generated_reports(data_handler, max_per_session)
  default_data = data_handler.new_table_with_default_values('generated_reports', GeneratedReport.columns_hash)

  index = 0
  max_index = ReportTemplate.count * max_per_session

  data = default_data

  report_templates = ReportTemplate.all
  user_sessions = UserSession.all
  report_templates.zip(user_sessions).each do |report_template, user_session|
    max_per_session.times do
      data[:name] = "#{user_session.user.first_name} report"
      data[:report_template_id] = report_template.id
      data[:user_session_id] = user_session.id
      data[:report_for] = report_template.report_for
      data[:participant_id] = user_session.user.id
      data_handler.store_data(data)

      p "#{index += 1}/#{max_index} generated reports created"
    end
  end
  data_handler.save_data_to_db
  p 'Successfully added GeneratedReports to database!'
end

# rubocop:enable Rails/Output
