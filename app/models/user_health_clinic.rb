# frozen_string_literal: true

class UserHealthClinic < ApplicationRecord
  has_paper_trail
  belongs_to :user
  belongs_to :health_clinic

  before_destroy :deactivate_health_clinic_admin

  private

  def deactivate_health_clinic_admin
    user.deactivate! if user.user_health_clinics.size.eql?(1)
  end
end
