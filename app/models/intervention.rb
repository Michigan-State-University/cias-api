# frozen_string_literal: true

class Intervention < ApplicationRecord
  extend FriendlyId
  include AASM
  include BodyInterface
  include DefaultValues
  belongs_to :user
  has_many :questions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :answers, dependent: :restrict_with_exception, through: :questions

  friendly_id :name, use: :slugged

  before_validation :assign_default_values

  attr_accessor :status_event

  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :type, :name, presence: true
  validates :status_event, inclusion: { in: %w[broadcast close] }, allow_nil: true

  aasm.attribute_name :status
  aasm do
    state :draft, initial: true
    state :published, :finished

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

  private

  def assign_default_values
    self.settings ||= retrive_default_values('settings')
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/intervention'
  end

  def should_generate_new_friendly_id?
    slug.blank? || name_changed?
  end
end
