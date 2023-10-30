# frozen_string_literal: true

class ImportedFile < ApplicationRecord
  has_one_attached :file, dependent: :purge_later
end
