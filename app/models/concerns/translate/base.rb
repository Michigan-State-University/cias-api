# frozen_string_literal: true

class Translate::Base
  attr_accessor :source, :translator, :source_language_name_short, :destination_language_name_short

  def initialize(source, translator, source_language_name_short, destination_language_name_short)
    @source = source
    @translator = translator
    @source_language_name_short = source_language_name_short
    @destination_language_name_short = destination_language_name_short
  end

  def execute
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
