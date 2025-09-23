# frozen_string_literal: true

class Hl7::AnswersMapper < Hl7::BaseMapper
  # rubocop:disable Layout/LineLength
  SEGMENT_TYPE = 'OBX' # The OBX segment is used to transmit a single observation or observation fragment. It represents the smallest indivisible unit of a report.
  VALUE_TYPE = 'ST' # String Data. -> https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0125
  OBSERVATION_RESULT_STATUS = 'F' # Final results; Can only be changed with a corrected result -> https://hl7-definition.caristix.com/v2/HL7v2.5/Fields/OBX.11
  # rubocop:enable Layout/LineLength

  def self.call(user_session_id)
    new(user_session_id).call
  end

  def call
    user_session.answers.hfhs.map.with_index do |answer, index|
      "#{SEGMENT_TYPE}|#{index + 1}|#{VALUE_TYPE}|#{code_desc(answer)}||#{answer_data(answer)}||||||#{OBSERVATION_RESULT_STATUS}|||#{date_of_answer}"
    end
  end

  private

  def code_desc(answer)
    answer.decrypted_body.dig('data', 0, 'var')
  end

  def answer_data(answer)
    answer.decrypted_body.dig('data', 0, 'hfh_value')
  end

  def date_of_answer
    @date_of_answer ||= user_session.finished_at.in_time_zone(report_timezone).strftime('%Y%m%d%H%M')
  end
end
