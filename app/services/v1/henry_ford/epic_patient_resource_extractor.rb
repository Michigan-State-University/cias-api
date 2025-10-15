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

  def epic_sex(resource)
    resource[:entry][0][:resource][:gender]
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
end
