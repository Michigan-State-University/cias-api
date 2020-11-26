# frozen_string_literal: true

class SessionJob < ApplicationJob
  def perform(*_args)
    raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
  end
end
