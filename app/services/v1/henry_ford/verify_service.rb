# frozen_string_literal: true

class V1::HenryFord::VerifyService
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

  def call
    @patient = Api::EpicOnFhir::PatientVerification.call(first_name, last_name, parsed_dob, phone_number, phone_type, zip_code, mrn)
    @appointments = Api::EpicOnFhir::Appointments.call(epic_patient_id)

    create_or_find_resource!
    assign_patient_details!

    resource
  end

  private

  %w[first_name last_name sex dob zip_code phone_number phone_type mrn].each do |param|
    define_method :"#{param}" do
      patient_params[param]
    end
  end

  def parsed_dob
    Date.parse(dob).strftime('%Y-%m-%d')
  end

  def epic_patient_id
    patient.dig(:entry, 0, :resource, :id)
  end

  def hfhs_patient_id
    system_identifier_details&.dig(:value)
  end

  def system_identifier_details
    @system_identifier_details ||= patient.dig(:entry, 0, :resource, :identifier)
                      .find { |system_identifier| system_identifier.dig(:type, :text) == SYSTEM_IDENTIFIER }
  end

  def hfhs_visit_id
    appointment = filtered_appointments
                    .sort_by! { |encounter| DateTime.parse(encounter.dig(:resource, :start)) }
                    .first

    raise EpicOnFhir::NotFound, I18n.t('epic_on_fhir.error.appointments.not_found') if appointment.blank?

    visit_id = appointment&.dig(:resource, :identifier, 0, :value)

    location_id = available_locations.where("LOWER(CONCAT(department, ' ', name)) LIKE ?",
                                            appointment
                                              .dig(:resource, :participant)
                                              .find { |participant| participant.dig(:actor, :reference).downcase.include?('location') }
                                              &.dig(:actor, :display)
                                              &.downcase.to_s).first.external_id

    "_#{location_id}_#{visit_id}"
  end

  def create_or_find_resource!
    @resource = HfhsPatientDetail.find_or_create_by!(
      patient_id: hfhs_patient_id,
      first_name: first_name,
      last_name: last_name,
      dob: Date.parse(dob),
      gender: sex,
      zip: zip_code,
      phone_type: phone_type,
      phone_number: phone_number
    )
    resource.update!(visit_id: hfhs_visit_id)
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
                   &.find { |participant| participant.dig(:actor, :reference)&.downcase&.include?('location') }&.dig(:actor, :display)

      valid_appointment?(location, parsed_date)
    end
  end

  def valid_appointment?(location, parsed_date)
    if ENV.fetch('HFHS_APPOINTMENTS_FROM_PAST', 0).to_i == 1
      available_location?(location)
    else
      available_location?(location) && (parsed_date&.today? || parsed_date&.future?)
    end
  end

  def available_location?(location)
    return false if location.blank?

    location.downcase.in?(intervention_locations)
  end

  def intervention_locations
    @intervention_locations ||= available_locations.map { |location| "#{location.department} #{location.name}".downcase }
  end

  def available_locations
    @available_locations ||= Session.find(session_id).intervention.clinic_locations
  end
end
