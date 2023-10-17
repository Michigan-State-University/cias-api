# frozen_string_literal: true

class ImportFile < ApplicationRecord
  has_one_attached :file, dependent: :purge_later
end
