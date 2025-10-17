# frozen_string_literal: true

class ConcurrentEditException < StandardError
  def initialize(msg = I18n.t('exceptions.concurrent_edit'))
    super
  end
end
