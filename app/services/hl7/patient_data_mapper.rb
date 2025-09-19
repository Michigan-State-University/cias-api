# frozen_string_literal: true

class Hl7::PatientDataMapper
  FIRST_SEGMENT_TYPE = 'MSH' # Message Header -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/MSH
  ENCODING_CHARACTERS = '^~\\&' # https://hl7-definition.caristix.com/v2/HL7v2.5/Fields/MSH.2
  MSH_SENDING_APPLICATION = 'HTD' # https://hl7-definition.caristix.com/v2/HL7v2.5/Fields/MSH.3
  MSH_SENDING_FACILITY = 'HFHS'
  MSH_RECEIVING_FACILITY = 'HFH'
  MSH_VERSION_ID = '2.3' # https://hl7-definition.caristix.com/v2/HL7v2.5/Fields/MSH.12

  SECOND_SEGMENT_TYPE = 'PID' # Patient Identification -> https://hl7-definition.caristix.com/v2/HL7v2.5/Segments/PID

  def self.call(user_id, user_session_id, msh_message_type, msh_trigger_event)
    new(user_id, user_session_id, msh_message_type, msh_trigger_event).call
  end

  def initialize(user_id, user_session_id, msh_message_type, msh_trigger_event)
    @user = User.find(user_id)
    @user_session = UserSession.find(user_session_id)
    @msh_message_type = msh_message_type # https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0076
    @msh_trigger_event = msh_trigger_event # https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0003
  end

  def call
    # rubocop:disable Layout/LineLength
    %W[#{FIRST_SEGMENT_TYPE}|^~\\&|#{MSH_SENDING_APPLICATION}|#{MSH_SENDING_FACILITY}||#{MSH_RECEIVING_FACILITY}|#{date_now}||#{msh_message_type}^#{msh_trigger_event}|#{message_count}|#{ENV.fetch('PROCESSING')}|#{MSH_VERSION_ID}|||
       #{SECOND_SEGMENT_TYPE}|||#{user.hfhs_patient_detail.patient_id}||#{user.hfhs_patient_detail.last_name}^#{user.hfhs_patient_detail.first_name}||#{dob_in_correct_format}|#{sex}]
    # rubocop:enable Layout/LineLength
  end

  attr_reader :user, :user_session, :msh_message_type, :msh_trigger_event

  private

  def date_now
    DateTime.now.in_time_zone('Eastern Time (US & Canada)').strftime('%Y%m%d%H%M')
  end

  def dob_in_correct_format
    user.hfhs_patient_detail.dob&.to_datetime&.strftime('%Y%m%d')
  end

  def sex
    user.hfhs_patient_detail.sex || 'U' # https://hl7-definition.caristix.com/v2/HL7v2.5/Tables/0001
  end

  # https://hl7-definition.caristix.com/v2/HL7v2.5/Fields/MSH.10
  def message_count
    user_session.answers.hfhs.count
  end
end
