# frozen_string_literal: true

class Clone::Base
  attr_accessor :source, :outcome, :options

  def initialize(source, **options)
    @source = source
    @outcome = @source.dup
    @outcome.assign_attributes(options)
    @outcome.save!
  end

  def execute
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
