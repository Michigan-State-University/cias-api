# frozen_string_literal: true

module DefaultValues
  def assign_default_values(attr)
    default_values_dictionary[ctx.downcase][attr.to_s]
  end

  private

  def ctx
    constant_segment = to_s.deconstantize
    constant_segment.empty? ? to_s.demodulize : constant_segment
  end

  def default_values_dictionary
    @default_values_dictionary ||= YAML.load_file(Rails.root.join('app/models/concerns/default_values/dictionary.yml'))
  end
end
