# frozen_string_literal: true

module DefaultAttributes
  def assign_default_attributes(*attrs)
    attrs.each { |attr| self[attr] = retrive_values(attr) }
  end

  private

  def default_attributes_dictionary
    @default_attributes_dictionary ||= YAML.load_file(Rails.root.join('app/models/concerns/default_attributes/dictionary.yml'))
  end

  def retrive_values(attr)
    default_attributes_dictionary[self.class.name.deconstantize.downcase][attr.to_s]
  end
end
