# frozen_string_literal: true

class V1::Ehr::VerifyService
  include V1::Ehr::EpicPatientResourceExtractor

  SYSTEM_IDENTIFIER = ENV.fetch('EPIC_ON_FHIR_SYSTEM_IDENTIFIER')

  def self.call(user, patient_params, session_id)
    new(user, patient_params, session_id).call
  end

  def initialize(user, patient_params, session_id)
    @user = user
    @patient_params = patient_params
    @session_id = session_id
  end

  attr_reader :user, :patient_params, :patient, :appointments, :session_id
  attr_accessor :resource

  # Confirm only after the appointment lookup succeeds, so a failed Continue can be retried.
  def call
    if patient_params[:id].present?
      load_confirmable_resource!
      epic_id = @resource.epic_id
    else
      @patient = Api::EpicOnFhir::PatientVerification.call(first_name, last_name, parsed_dob, phone_number, phone_type, zip_code, mrn)
      epic_id = epic_patient_id(@patient)
    end

    @appointments = Api::EpicOnFhir::Appointments.call(epic_id)
    create_or_find_resource!(epic_id) if @resource.nil?
    @resource.update!(visit_id: ehr_visit_id, **confirmation_attributes)
    assign_patient_details!
    @resource
  end

  private

  %w[first_name last_name sex dob zip_code phone_number phone_type mrn].each do |param|
    define_method :"#{param}" do
      patient_params[param]
    end
  end

  def parsed_dob
    return if dob.blank?

    Date.parse(dob).strftime('%Y-%m-%d')
  end

  def ehr_patient_id
    system_identifier_details&.dig(:value)
  end

  def system_identifier_details
    @system_identifier_details ||= patient.dig(:entry, 0, :resource, :identifier)
                                          .find { |system_identifier| system_identifier.dig(:type, :text) == SYSTEM_IDENTIFIER }
  end

  def ehr_visit_id
    appointment = filtered_appointments
                    .sort_by! { |encounter| DateTime.parse(encounter.dig(:resource, :start)) }
                    .first

    raise EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.appointments.not_found') if appointment.blank?

    visit_id = appointment&.dig(:resource, :identifier, 0, :value)

    location, location_auxiliary_id = verify_by_identifier(appointment)
    location ||= verify_by_name(appointment, location_auxiliary_id)

    location_id = location.external_id

    "_#{location_id}_#{visit_id}"
  end

  def verify_by_name(appointment, location_identifer)
    appointment_name = appointment
                         .dig(:resource, :participant)
                         .find { |participant| participant.dig(:actor, :reference).downcase.include?('location') }
                         &.dig(:actor, :display)
                         &.downcase.to_s

    location = available_locations
                 .where("regexp_replace(LOWER(CONCAT(department, ' ', external_name)), '^\s*', '') LIKE ?", appointment_name)
                 .first

    appointment_location_id = location.epic_identifier
    location.update!(auxiliary_epic_identifier: location_identifer)
    Rails.logger.debug { "[EHR verify] clinic location matched by name: epic_identifier=#{appointment_location_id}, auxiliary=#{location_identifer}" }

    location
  end

  def verify_by_identifier(appointment)
    appointment_location_id = appointment
                                .dig(:resource, :participant)
                                .find { |participant| participant.dig(:actor, :reference).downcase.include?('location') }
                                &.dig(:actor, :reference)
                                &.to_s

    appointment_location_auxiliary_id = appointment_location_id.sub('Location/', '')
    [available_locations.where(auxiliary_epic_identifier: appointment_location_auxiliary_id).first, appointment_location_auxiliary_id]
  end

  def load_confirmable_resource!
    @resource = HfhsPatientDetail.find_by(id: patient_params[:id])
    return if @resource&.epic_id.present? && confirmable_by_user?

    raise ActiveRecord::RecordNotFound, I18n.t('ehr.error.patient.draft_not_found')
  end

  def confirmable_by_user?
    (@resource.pending? && @resource.drafted_by_id == user.id) || user.hfhs_patient_detail_id == @resource.id
  end

  def confirmation_attributes
    user.preview_session? ? {} : { pending: false }
  end

  # epic_id stays out of the key so older rows without it are found, not duplicated.
  def create_or_find_resource!(epic_id)
    @resource = HfhsPatientDetail.find_or_create_by!(
      patient_id: ehr_patient_id,
      first_name: epic_first_name(@patient),
      last_name: epic_last_name(@patient),
      dob: epic_dob(@patient),
      sex: epic_sex(@patient),
      zip_code: epic_zip_code(@patient) || zip_code,
      phone_type: epic_phone_type(@patient),
      phone_number: epic_phone_number(@patient),
      provided_first_name: first_name,
      provided_last_name: last_name,
      provided_dob: dob,
      provided_sex: sex,
      provided_zip: zip_code,
      provided_phone_type: phone_type,
      provided_phone_number: phone_number
    ) { |record| record.epic_id = epic_id }
    @resource.update!(epic_id: epic_id) if @resource.epic_id != epic_id
  end

  def assign_patient_details!
    return if user.preview_session?

    user.update(hfhs_patient_detail: @resource)
  end

  def filtered_appointments
    @appointments[:entry].find_all do |appointment|
      start = appointment.dig(:resource, :start)
      parsed_date = Date.parse(start) if start.present?

      location = appointment
                   &.dig(:resource, :participant)
                   &.find { |participant| participant.dig(:actor, :reference)&.downcase&.include?('location') }
                   &.dig(:actor, :display)

      location_identifier = appointment
                              &.dig(:resource, :participant)
                              &.find { |participant| participant.dig(:actor, :reference)&.downcase&.include?('location') }
                              &.dig(:actor, :reference)
                              &.sub('Location/', '')

      valid_appointment?(location, location_identifier, parsed_date)
    end
  end

  def valid_appointment?(location, location_identifier, parsed_date)
    if Ehr::Settings.fetch('EHR_APPOINTMENTS_FROM_PAST').to_i == 1
      available_location?(location, location_identifier)
    else
      available_location?(location, location_identifier) && (parsed_date&.today? || parsed_date&.future?)
    end
  end

  def available_location?(location, location_identifier)
    return false if location.blank?

    location.downcase.in?(intervention_locations) || location_identifier.in?(intervention_locations_identifiers)
  end

  def intervention_locations
    @intervention_locations ||= available_locations.map { |location| "#{location.department} #{location.external_name}".downcase.lstrip }
  end

  def intervention_locations_identifiers
    @intervention_locations_identifiers ||= available_locations.pluck(:auxiliary_epic_identifier).compact.uniq
  end

  def available_locations
    @available_locations ||= Session.find(session_id).intervention.clinic_locations
  end
end
