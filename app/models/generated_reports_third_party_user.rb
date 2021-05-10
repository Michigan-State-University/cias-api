# frozen_string_literal: true

class GeneratedReportsThirdPartyUser < ApplicationRecord
  belongs_to :third_party, class_name: 'User'
  belongs_to :generated_report, class_name: 'GeneratedReport'
end
