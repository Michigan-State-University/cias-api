# frozen_string_literal: true

class LogJob < ApplicationJob
  queue_as :log

  def perform(*_args)
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
