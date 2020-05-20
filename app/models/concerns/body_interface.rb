# frozen_string_literal: true

module BodyInterface
  extend ActiveSupport::Concern
  include BodyInterface::Guard

  included do
    before_save :extend_instance
  end

  def extend_instance
    guard_protection
    body&.each do |key, value|
      instance_variable_set("@#{key}", value)
      self.class.send(:attr_reader, key)
    rescue NameError => e
      errors.add(key, e.message)
    end
  end
end
