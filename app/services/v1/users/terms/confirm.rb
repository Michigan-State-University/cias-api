# frozen_string_literal: true

class V1::Users::Terms::Confirm
  def self.call(fields, email, password)
    new(fields, email, password).call
  end

  def initialize(fields, email, password)
    @fields = fields
    @email = email
    @password = password
  end

  def call
    user.update!(fields) if user.valid_password?(password)
  end

  private

  attr_reader :fields, :email, :password

  def user
    User.find_by!(email: email)
  end
end
