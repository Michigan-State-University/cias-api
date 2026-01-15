# frozen_string_literal: true

class Tag < ApplicationRecord
  CURRENT_VERSION = '1'

  validates :name, presence: true, uniqueness: true

  has_many :tag_interventions, dependent: :destroy
  has_many :interventions, through: :tag_interventions

  scope :filter_by_name, ->(name) { where('name ILIKE ?', "%#{name}%") if name.present? }
  scope :not_assigned_to_intervention, lambda { |intervention_id|
    where.not(id: TagIntervention.where(intervention_id: intervention_id).select(:tag_id)) if intervention_id.present?
  }
end
