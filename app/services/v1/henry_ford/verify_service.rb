# frozen_string_literal: true

class V1::HenryFord::VerifyService
  def self.call(user, patient_params)
    new(user, patient_params).call
  end

  def initialize(user, patient_params)
    @user = user
    @patient_params = patient_params
  end

  attr_reader :user, :patient_params
  attr_accessor :patient_details

  def call
    if mrn.present?
      @patient_details = HfhsPatientDetail.find_by!(patient_id: mrn)
    else
      details = HfhsPatientDetail.where(first_name: first_name, last_name: last_name, sex: sex, dob: parsed_dob, zip_code: zip_code)
      verify_found_details(details)

      @patient_details = details.first
    end

    assign_patient_details!

    @patient_details
  end

  private

  %w[first_name last_name sex dob zip_code find_by mrn].each do |param|
    define_method :"#{param}" do
      patient_params[param]
    end
  end

  def parsed_dob
    Date.parse(dob)
  end

  def assign_patient_details!
    return if user.guest? || user.preview_session?

    user.update(hfhs_patient_detail: @patient_details)
  end

  def verify_found_details(details)
    raise ActiveRecord::RecordNotFound, I18n.t('hfhs_patient_detail.not_found') if details.empty?
    raise ActiveRecord::RecordNotUnique, I18n.t('hfhs_patient_detail.not_unique') if details.size > 1
  end
end
