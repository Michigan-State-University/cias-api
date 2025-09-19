# frozen_string_literal: true

class Hl7::ReportMapper
  FIRST_SEGMENT_TYPE = 'PV1' # Patient Visit -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/PV1
  PATIENT_CLASS = 'O' # Outpatient -> https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0004

  SECOND_SEGMENT_TYPE = 'TXA' # Transcription Document Header -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/TXA
  DOCUMENT_COMPLETION_STATUS = 'AU' #	Authenticated -> https://hl7-definition.caristix.com/v2/HL7v2.6/Tables/0271
  REPORT_TYPE = 'DASST-D' # provided by HFHS
  DOCUMENT_AVAILABILITY_STATUS = 'AV' # Available for patient care ->https://hl7-definition.caristix.com/v2/HL7v2.6/Tables/0273

  THIRD_SEGMENT_TYPE = 'OBX' # Observation/Result -> https://hl7-definition.caristix.com/v2/HL7v2.6/Segments/OBX
  OBX_VALUE_TYPE = 'ED' # Encapsulated Data -> https://hl7-definition.caristix.com/v2/HL7v2.6/Tables/0125
  OBSERVATION_VALUE = 'EpicWBS^PDF^Base64' # -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/OBX

  def self.call(generated_report_id, user_session_id)
    new(generated_report_id, user_session_id).call
  end

  def initialize(generated_report_id, user_session_id)
    @report = GeneratedReport.find(generated_report_id)
    @user_session = UserSession.find(user_session_id)
  end

  def call
    %W[
      #{FIRST_SEGMENT_TYPE}||#{PATIENT_CLASS}|||||||||||||||||#{visit_id}
      #{SECOND_SEGMENT_TYPE}||#{REPORT_TYPE}||#{finish_date}||||||||#{hfhs_patient_id}|||||#{DOCUMENT_COMPLETION_STATUS}||#{DOCUMENT_AVAILABILITY_STATUS}
      #{THIRD_SEGMENT_TYPE}|1|#{OBX_VALUE_TYPE}|||#{OBSERVATION_VALUE}^#{file_base64}
    ]
  end

  attr_reader :report, :user_session

  private

  def visit_id
    user_session.user.hfhs_patient_detail.visit_id
  end

  def finish_date
    report.created_at.in_time_zone('Eastern Time (US & Canada)').strftime('%Y%m%d%H%M')
  end

  def hfhs_patient_id
    user_session.user.hfhs_patient_detail.patient_id
  end

  def file_base64
    Base64.strict_encode64(report.pdf_report.blob.download)
  end
end
