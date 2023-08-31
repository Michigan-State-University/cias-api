# frozen_string_literal: true

class Answer::ThirdParty < Answer
  def csv_row_value(data)
    presented_data = data.slice('value', 'report_template_ids', 'numeric_value')
    presented_data['report_template'] = map_id_to_name(presented_data.delete('report_template_ids'))
    presented_data
  end

  private

  def map_id_to_name(report_template_ids)
    report_template_ids.map do |report_template_id|
      ReportTemplate.find(report_template_id).name
    end
  end
end
