# frozen_string_literal: true

class GeneratedReportsThirdPartyUser < ApplicationRecord
  has_paper_trail
  belongs_to :third_party, class_name: 'User'
  belongs_to :generated_report, class_name: 'GeneratedReport'
end
