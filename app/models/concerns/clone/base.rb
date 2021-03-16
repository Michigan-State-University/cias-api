# frozen_string_literal: true

class Clone::Base
  attr_accessor :source, :outcome, :options, :clean_formulas, :position

  def initialize(source, **options)
    @source = source
    @outcome = @source.dup
    @clean_formulas = options.delete(:clean_formulas)
    @position = options.delete(:position)
    @outcome.assign_attributes(options)
    @outcome.duplicated = true if outcome.is_a?(Question)
    @outcome.save!
  end

  def execute
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
