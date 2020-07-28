# frozen_string_literal: true

class Intervention < ApplicationRecord
  extend FriendlyId
  include AASM
  include BodyInterface
  extend DefaultValues
  belongs_to :user
  belongs_to :problem, optional: true
  has_many :questions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :answers, dependent: :restrict_with_exception, through: :questions

  friendly_id :name, use: :slugged

  attribute :settings, :json, default: assign_default_values('settings')
  attribute :position, :integer, default: 0
  attribute :body, :json, default: { data: [] }

  attr_accessor :status_event

  validates :name, presence: true
  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :status_event, inclusion: { in: %w[broadcast close] }, allow_nil: true

  aasm.attribute_name :status
  aasm do
    state :draft, :finished
    state :published, initial: true

    event :broadcast do
      transitions from: :draft, to: :published
    end

    event :close do
      transitions from: :published, to: :finished
    end
  end

  scope :allow_guests, -> { where(allow_guests: true) }

  def propagate_settings
    return unless settings_changed?

    narrator = Hash[settings['narrator'].to_a - settings_was['narrator'].to_a]
    questions.each do |question|
      question.narrator['settings'].merge!(narrator)
      question.save!
    end
  end

  def integral_update
    propagate_settings
    public_send(status_event) unless status_event.nil?
    save!
  end

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end

  private

  def json_schema_path
    @json_schema_path ||= 'db/schema/intervention'
  end
end
