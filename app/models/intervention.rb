# frozen_string_literal: true

class Intervention < ApplicationRecord
  include BodyInterface
  include DefaultValues
  belongs_to :user
  has_many :questions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :answers, dependent: :restrict_with_exception, through: :questions

  before_validation :assign_default_values

  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }
  validates :type, :name, presence: true

  def propagate_settings
    if settings_changed?
      narrator = Hash[settings['narrator'].to_a - settings_was['narrator'].to_a]
      questions.each do |question|
        question.narrator['settings'].merge!(narrator)
        question.save!
      end
    end
  end

  private

  def assign_default_values
    self.settings ||= retrive_default_values('settings')
  end

  def json_schema_path
    @json_schema_path ||= 'db/schema/intervention'
  end
end
