# frozen_string_literal: true

class V1::ApplicationService
  def self.call(...)
    new(...).call
  end

  def call
    raise(NotImplementedError)
  end
end
