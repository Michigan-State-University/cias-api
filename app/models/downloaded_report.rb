# frozen_string_literal: true

class DownloadedReport < ApplicationRecord
  belongs_to :user
  belongs_to :generated_report
end
