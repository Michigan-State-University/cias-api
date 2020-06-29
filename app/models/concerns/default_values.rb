# frozen_string_literal: true

module DefaultValues
  def retrive_default_values(attr)
    default_values_dictionary[self.class.name.deconstantize.downcase][attr.to_s]
  end

  private

  def default_values_dictionary
    @default_values_dictionary ||= YAML.load_file(Rails.root.join('app/models/concerns/default_values/dictionary.yml'))
  end
end
