# frozen_string_literal: true

class Answer < ApplicationRecord
  include BodyInterface
  belongs_to :user, optional: true
  belongs_to :question

  delegate :subclass_name, :settings, :order, :title, :subtitle, :formula, to: :question, allow_nil: true

  validate :type_integrity_validator

  private

  def type_integrity_validator
    return if type.demodulize.eql? subclass_name

    errors.add(:type, 'broken type integrity')
  end
end
