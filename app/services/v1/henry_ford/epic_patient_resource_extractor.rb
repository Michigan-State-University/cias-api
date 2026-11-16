# frozen_string_literal: true

module V1::HenryFord::EpicPatientResourceExtractor
  def epic_first_name(resource)
    resource[:entry][0][:resource][:name][0][:given][0]
  end

  def epic_last_name(resource)
    resource[:entry][0][:resource][:name][0][:family]
  end

  def epic_dob(resource)
    Date.parse(resource[:entry][0][:resource][:birthDate])
  end

  # FHIR administrative-gender (male/female/other/unknown) -> HL7 table 0001
  # (M/F/O/U): the format stored since 2023 and sent as-is in PID.8.
  def epic_sex(resource)
    resource.dig(:entry, 0, :resource, :gender).to_s[0]&.upcase
  end

  def epic_zip_code(resource)
    resource[:entry][0][:resource][:address].detect { |address| address[:use].eql?('home') }&.dig(:postalCode)
  end

  def epic_phone_type(resource)
    resource[:entry][0][:resource][:telecom][0][:use]
  end

  def epic_phone_number(resource)
    resource[:entry][0][:resource][:telecom][0][:value]
  end

  # Aztec-code path only: the phone shown (masked) on the confirm screen. A mobile
  # number is preferred, otherwise the first phone Epic lists (by rank); email
  # and other telecom entries are skipped. The manual path keeps telecom[0], as
  # its stored phone is part of the lookup key for returning patients.
  def epic_preferred_phone(resource)
    phones = Array(resource.dig(:entry, 0, :resource, :telecom)).select { |telecom| telecom[:system] == 'phone' }
    phones = phones.each_with_index.sort_by { |telecom, index| [telecom[:rank] || Float::INFINITY, index] }.map(&:first)

    phones.find { |telecom| telecom[:use] == 'mobile' } || phones.first
  end

  # A `use` outside home/mobile/work (e.g. `temp`) is stored as unknown rather
  # than failing the whole scan.
  def epic_preferred_phone_type(resource)
    use = epic_preferred_phone(resource)&.dig(:use)
    use if HfhsPatientDetail.phone_types.key?(use)
  end

  def epic_patient_id(resource)
    resource[:entry][0][:resource][:id]
  end
end
