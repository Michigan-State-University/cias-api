# frozen_string_literal: true

module BodyInterface
  extend ActiveSupport::Concern
  include BodyInterface::Guard
  include BodyInterface::Validations

  included do
    before_save :guard_protection
  end
end
