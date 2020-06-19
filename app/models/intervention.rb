# frozen_string_literal: true

class Intervention < ApplicationRecord
  include BodyInterface
  belongs_to :user
  has_many :questions, dependent: :restrict_with_exception, inverse_of: :intervention
  has_many :answers, dependent: :restrict_with_exception, through: :questions

  validates :settings, json: { schema: -> { Rails.root.join("#{json_schema_path}/settings.json").to_s }, message: ->(err) { err } }

  validates :type, :name, presence: true

  private

  def json_schema_path
    @json_schema_path ||= 'db/schema/intervention'
  end
end
