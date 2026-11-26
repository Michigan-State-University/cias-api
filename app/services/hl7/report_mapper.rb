# frozen_string_literal: true

class Hl7::ReportMapper < Hl7::BaseMapper
  FIRST_SEGMENT_TYPE = 'PV1' # Patient Visit -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/PV1
  PATIENT_CLASS = 'O' # Outpatient -> https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0004

  SECOND_SEGMENT_TYPE = 'TXA' # Transcription Document Header -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/TXA
  DOCUMENT_COMPLETION_STATUS = 'AU' #	Authenticated -> https://hl7-definition.caristix.com/v2/HL7v2.6/Tables/0271
  DOCUMENT_AVAILABILITY_STATUS = 'AV' # Available for patient care ->https://hl7-definition.caristix.com/v2/HL7v2.6/Tables/0273

  THIRD_SEGMENT_TYPE = 'OBX' # Observation/Result -> https://hl7-definition.caristix.com/v2/HL7v2.6/Segments/OBX
  OBX_VALUE_TYPE = 'ED' # Encapsulated Data -> https://hl7-definition.caristix.com/v2/HL7v2.6/Tables/0125

  def self.call(generated_report_id, user_session_id)
    new(generated_report_id, user_session_id).call
  end

  def initialize(generated_report_id, user_session_id)
    super(user_session_id)
    @report = GeneratedReport.find(generated_report_id)
  end

  def call
    %W[
      #{FIRST_SEGMENT_TYPE}||#{PATIENT_CLASS}|||||||||||||||||#{visit_id}
      #{SECOND_SEGMENT_TYPE}||#{document_type}||#{finish_date}||||||||#{ehr_patient_id}|||||#{DOCUMENT_COMPLETION_STATUS}||#{DOCUMENT_AVAILABILITY_STATUS}
      #{THIRD_SEGMENT_TYPE}|1|#{OBX_VALUE_TYPE}|||#{observation_value_prefix}^#{file_base64}
    ]
  end

  attr_reader :report

  private

  # TXA-2 -> https://hl7-definition.caristix.com/v2/HL7v2.5/Fields/TXA.2
  def document_type
    Ehr::Settings.hl7_document_type
  end

  # OBX-5 prefix -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/OBX
  def observation_value_prefix
    Ehr::Settings.hl7_observation_value_prefix
  end

  def visit_id
    user_session.user.hfhs_patient_detail.visit_id
  end

  def finish_date
    report.created_at.in_time_zone(report_timezone).strftime('%Y%m%d%H%M')
  end

  def ehr_patient_id
    user_session.user.hfhs_patient_detail.patient_id
  end

  def file_base64
    Base64.strict_encode64(report.pdf_report.blob.download)
  end
end
