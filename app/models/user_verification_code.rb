# frozen_string_literal: true

class UserVerificationCode < ApplicationRecord
  belongs_to :user
end
