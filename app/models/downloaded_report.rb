# frozen_string_literal: true

class DownloadedReport < ApplicationRecord
  belongs_to :user
  belongs_to :generated_report

  def downloaded?
    downloaded
  end
end
