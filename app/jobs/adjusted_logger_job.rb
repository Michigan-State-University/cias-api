# frozen_string_literal: true

class AdjustedLoggerJob < ApplicationJob
  queue_as :loggers

  def perform(*_args)
    raise NotImplementedError, 'subclass did not define #perform'
  end
end
