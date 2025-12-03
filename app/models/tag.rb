# frozen_string_literal: true

class Tag < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :tag_interventions, dependent: :destroy
  has_many :interventions, through: :tag_interventions

  scope :filter_by_name, ->(name) { where('name ILIKE ?', "%#{name}%") if name.present? }
end
