# frozen_string_literal: true

class GoogleLanguage < ApplicationRecord
  has_many :interventions, dependent: :nullify
end
