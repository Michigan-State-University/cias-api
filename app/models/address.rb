# frozen_string_literal: true

class Address < ApplicationRecord
  belongs_to :user, inverse_of: :address

  def formatted
    %(
      #{user.full_name}
      #{street} #{apartment_number} #{building_address}
      #{city} #{state_abbreviation} #{zip_code}
      #{country}
    )
  end
end
