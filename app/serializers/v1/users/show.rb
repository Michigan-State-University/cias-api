# frozen_string_literal: true

class V1::Users::Show < BaseSerializer
  def cache_key
    "user/#{@user.id}-#{@user.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @user.id,
      email: @user.email,
      full_name: @user.full_name,
      first_name: @user.first_name,
      last_name: @user.last_name,
      phone: @user.phone,
      time_zone: @user.time_zone,
      active: @user.active,
      roles: @user.roles,
      avatar_url: provide_avatar_url,
      address_attributes: provide_address_attributes
    }
  end

  private

  def provide_avatar_url
    polymorphic_url(@user.avatar) if @user.avatar.attached?
  end

  def provide_address_attributes
    address = @user.address || ::NullAddress.new
    {
      name: address.name,
      country: address.country,
      state: address.state,
      state_abbreviation: address.state_abbreviation,
      city: address.city,
      zip_code: address.zip_code,
      street: address.street,
      building_address: address.building_address,
      apartment_number: address.apartment_number,
      formatted_usa: address.formatted_usa
    }
  end
end
