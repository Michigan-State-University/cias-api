# frozen_string_literal: true

module BodyInterface
  extend ActiveSupport::Concern
  include BodyInterface::Guard

  included do
    before_save :guard_protection
  end

  def body_data
    body['data']
  end

  def body_variable
    body['variable']
  end
end
