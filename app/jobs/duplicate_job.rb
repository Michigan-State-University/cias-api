# frozen_string_literal: true

class DuplicateJob < ApplicationJob
  queue_as :clone

  def perform(*_args)
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
