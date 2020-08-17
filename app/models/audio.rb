# frozen_string_literal: true

class Audio < ApplicationRecord
  has_one_attached :mp3

  validates :usage_counter, numericality: { greater_than_or_equal_to: 0 }

  def url
    Rails.application.routes.url_helpers.rails_blob_path(mp3, only_path: true)
  end
end
