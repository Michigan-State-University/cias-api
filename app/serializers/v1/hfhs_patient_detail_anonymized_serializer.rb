# frozen_string_literal: true

class V1::HfhsPatientDetailAnonymizedSerializer < V1Serializer
  attributes :id, :patient_id, :sex, :zip_code

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

      digits = phone.to_s.gsub(/\D/, '')
      return '****' if digits.length <= 4

      "#{'*' * (digits.length - 4)}#{digits[-4..]}"
    end
  end
end
