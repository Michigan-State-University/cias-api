# frozen_string_literal: true

class Tag < ApplicationRecord
  CURRENT_VERSION = '1'

  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id }

  has_many :tag_interventions, dependent: :destroy
  has_many :interventions, through: :tag_interventions

  scope :filter_by_name, ->(name) { where('name ILIKE ?', "%#{name}%") if name.present? }
  scope :not_assigned_to_intervention, lambda { |intervention_id|
    where.not(id: TagIntervention.where(intervention_id: intervention_id).select(:tag_id)) if intervention_id.present?
  }
  scope :owned_by, ->(user) { where(user: user) }
end
