# frozen_string_literal: true

class Clone::Base
  attr_accessor :source, :outcome, :options, :clean_formulas, :position

  def initialize(source, **options)
    p "CLONE DEBUG #{source.class.name}"
    p "CLONE DEBUG #{source.id}"
    @source = source
    @outcome = @source.dup
    @clean_formulas = options.delete(:clean_formulas)
    @position = options.delete(:position)
    @outcome.variable = options[:params][:variable] if options[:params].present? && options[:params][:variable].present?
    options.delete(:params)
    @outcome.assign_attributes(options)
    @outcome.duplicated = true if outcome.is_a?(Question)
    @outcome.save!
  end

  def execute
    raise NotImplementedError, "subclass did not define #{__method__}"
  end
end
