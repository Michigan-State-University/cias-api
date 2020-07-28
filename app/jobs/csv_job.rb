# frozen_string_literal: true

class CsvJob < ApplicationJob
  queue_as :default

  def perform(*_args)
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
