# frozen_string_literal: true

class CleanJob < ApplicationJob
  queue_as :active_storage_purge

  def perform(*_args)
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
