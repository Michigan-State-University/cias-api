# frozen_string_literal: true

class V1::Users::SmsTokens::Phone
  def initialize(user, phone_number, iso, prefix)
    @user = user
    @phone_number = phone_number
    @iso = iso
    @prefix = prefix
  end

  attr_reader :user, :phone_number, :iso, :prefix

  def phone
    user_without_phone? ? new_phone : user_with_phone
  end

  private

  def user_without_phone?
    user.phone.blank?
  end

  def new_phone
    Phone.create!(number: phone_number, prefix: prefix, iso: iso, user: user) if phone_params_exists?
  end

  def user_with_phone
    if phone_not_changed?
      user.phone
    else
      user.phone.delete
      new_phone
    end
  end

  def phone_not_changed?
    user.phone.number.eql?(phone_number) && user.phone.iso.eql?(iso) && user.phone.prefix.eql?(prefix)
  end

  def phone_params_exists?
    iso.present? && phone_number.present? && prefix.present?
  end
end
