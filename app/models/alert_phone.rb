# frozen_string_literal: true

class AlertPhone < ApplicationRecord
  belongs_to :phone
  belongs_to :sms_plan
end
