# frozen_string_literal: true

module DefaultValues
  include MetaOperations

  def assign_default_values(attr)
    default_values_dictionary[de_constantize_modulize_name.downcase][attr.to_s]
  end

  private

  def default_values_dictionary
    @default_values_dictionary ||= YAML.load_file(Rails.root.join('app/models/concerns/default_values/dictionary.yml'))
  end
end
