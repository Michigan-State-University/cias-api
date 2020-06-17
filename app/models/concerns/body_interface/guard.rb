# frozen_string_literal: true

module BodyInterface::Guard
  def guard_protection
    prevent_flood_against_body
    prevent_flood_against_element
    prevent_name_error_exception
    prevent_instance_exploit
    dismiss_empty_elements
  end

  private

  def data_elements
    body_data&.each { |hash| yield(hash) }
  end

  def guard_dictionary
    @guard_dictionary ||= YAML.load_file(Rails.root.join('app/models/concerns/body_interface/guard/dictionary.yml'))
  end

  def reserved_words
    @reserved_words ||= guard_dictionary['reserved_words']
  end

  def permitted_elements
    @permitted_elements ||= guard_dictionary['permitted_elements']
  end

  def prevent_flood_against_body
    body&.keep_if { |key| key.eql?('data') }
  end

  def prevent_flood_against_element
    data_elements do |hash|
      hash.keep_if { |key| permitted_elements.include?(key) }
    end
  end

  def prevent_name_error_exception
    data_elements do |hash|
      hash.transform_keys! { |key| key.downcase.parameterize.underscore }
    end
  end

  def prevent_instance_exploit
    data_elements do |hash|
      hash.reject! { |key| reserved_words.include?(key) }
    end
  end

  def dismiss_empty_elements
    body_data&.delete_if(&:empty?)
  end
end
