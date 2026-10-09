# frozen_string_literal: true

# Serves the confirmation screen shown right after an Aztec code scan, before
# the patient has confirmed anything. Every attribute here is therefore
# deliberately partial: enough for a patient to recognise themselves, not
# enough to be useful to anybody else. Do NOT add plain attributes to this
# serializer - add a masked one.
class V1::HfhsPatientDetailAnonymizedSerializer < V1Serializer
  attributes :id

  attribute :first_name do |object|
    anonymize_name(object.first_name)
  end

  attribute :last_name do |object|
    anonymize_name(object.last_name)
  end

  attribute :dob do |object|
    anonymize_dob(object.dob)
  end

  attribute :phone_number do |object|
    anonymize_phone(object.phone_number)
  end

  attribute :mrn do |object|
    mask_except_last_four(object.patient_id)
  end

  class << self
    private

    def anonymize_name(name)
      return nil if name.blank?
      return '**' if name.length <= 2

      "#{name[0..1]}#{'*' * (name.length - 2)}"
    end

    def anonymize_dob(dob)
      return nil if dob.blank?

      date = dob.is_a?(String) ? Date.parse(dob) : dob
      date.year.to_s
    rescue StandardError
      nil
    end

    def anonymize_phone(phone)
      return nil if phone.blank?

      mask_except_last_four(phone.to_s.gsub(/\D/, ''))
    end

    def mask_except_last_four(value)
      return nil if value.blank?

      value = value.to_s
      return '****' if value.length <= 4

      "#{'*' * (value.length - 4)}#{value[-4..]}"
    end
  end
end
