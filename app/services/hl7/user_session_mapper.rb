# frozen_string_literal: true

class Hl7::UserSessionMapper
  FIRST_SEGMENT_TYPE = 'PV1' # Patient Visit -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/PV1
  PATIENT_CLASS = 'O' # 	Outpatient -> https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0004

  SECOND_SEGMENT_TYPE = 'OBR' # Observation Request -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/OBR
  RESULT_TYPE = 'F' # Final results; results stored and verified.  Can only be changed with a corrected result. -> https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0123

  def self.call(user_session_id)
    new(user_session_id).call
  end

  def initialize(user_session_id)
    @user_session = UserSession.find(user_session_id)
  end

  def call
    [
      Hl7::PatientDataMapper.call(user_session.user.id, user_session.id),
      "#{FIRST_SEGMENT_TYPE}||#{PATIENT_CLASS}|||||||||||||||||#{visit_id}",
      "#{SECOND_SEGMENT_TYPE}|||||||#{finished_date}||||||||||||||||||#{RESULT_TYPE}",
      Hl7::AnswersMapper.call(user_session.id)
    ].flatten
  end

  attr_reader :user_session

  private

  def visit_id
    user_session.user.hfhs_visit_id
  end

  def finished_date
    user_session.finished_at.strftime('%Y%m%d%H%M')
  end
end
