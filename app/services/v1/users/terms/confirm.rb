# frozen_string_literal: true

class V1::Users::Terms::Confirm
  def self.call(fields, email)
    new(fields, email).call
  end

  def initialize(fields, email)
    @fields = fields
    @email = email
  end

  def call
    user.update!(fields)
  end

  private

  attr_reader :fields, :email

  def user
    User.find_by!(email: email)
  end
end
