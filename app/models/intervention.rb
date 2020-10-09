# frozen_string_literal: true

class Intervention < ApplicationRecord
  extend DefaultValues
  extend FriendlyId
  include AASM
  include BodyInterface
  include Clone
  include FormulaInterface

  belongs_to :problem, inverse_of: :interventions, touch: true
  has_many :questions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :answers, dependent: :restrict_with_exception, through: :questions

  friendly_id :name, use: :slugged

  attribute :settings, :json, default: assign_default_values('settings')
  attribute :position, :integer, default: 0
  attribute :formula, :json, default: { payload: '', patterns: [] }
  attribute :body, :json, default: { data: [] }

  enum schedule: { days_after: 'days_after', days_after_fill: 'days_after_fill', exact_date: 'exact_date' }, _prefix: :schedule

  validates :name, presence: true
  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :formula, presence: true, json: { schema: -> { Rails.root.join("#{json_schema_path}/formula.json").to_s }, message: ->(err) { err } }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  def propagate_settings
    return unless settings_changed?

    narrator = Hash[settings['narrator'].to_a - settings_was['narrator'].to_a]
    questions.each do |question|
      question.narrator['settings'].merge!(narrator)
      question.execute_narrator
      question.save!
    end
  end

  def integral_update
    propagate_settings
    save!
  end

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  def perform_narrator_reflection(_placeholder)
    nil
  end

  private

  def json_schema_path
    @json_schema_path ||= 'db/schema/intervention'
  end
end
