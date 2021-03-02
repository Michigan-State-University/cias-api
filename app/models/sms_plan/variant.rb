# frozen_string_literal: true

class SmsPlan::Variant < ApplicationRecord
  belongs_to :sms_plan
end
