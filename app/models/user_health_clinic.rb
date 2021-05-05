# frozen_string_literal: true

class UserHealthClinic < ApplicationRecord
  belongs_to :user
  belongs_to :health_clinic
end
