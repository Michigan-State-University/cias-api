# frozen_string_literal: true

class UserHealthClinic < ApplicationRecord
  has_paper_trail
  belongs_to :user
  belongs_to :health_clinic
end
