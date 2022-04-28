# frozen_string_literal: true

class Clone::Base
  attr_accessor :source, :outcome, :options, :hidden, :clean_formulas, :position, :session_variables

  def initialize(source, **options)
    @source = source
    @outcome = @source.dup
    @session_variables = options.delete(:session_variables)
    @clean_formulas = options.delete(:clean_formulas)
    @hidden = options.delete(:hidden)
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
