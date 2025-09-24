# frozen_string_literal: true

class Hl7::GeneratedReportMapper < Hl7::BaseMapper
  MSH_MESSAGE_TYPE = 'MDM' # Medical document management -> https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0076
  MSH_TRIGGER_EVENT = 'T02' # MDM/ACK - Original document notification and content -> https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0003

  def self.call(user_session_id, report_id)
    new(user_session_id, report_id).call
  end

  def initialize(user_session_id, report_id)
    super(user_session_id)
    @report_id = report_id
  end

  def call
    [
      Hl7::PatientDataMapper.call(user_session.user.id, user_session.id, MSH_MESSAGE_TYPE, MSH_TRIGGER_EVENT),
      Hl7::ReportMapper.call(report_id, user_session.id)
    ].flatten
  end

  attr_reader :report_id
end
