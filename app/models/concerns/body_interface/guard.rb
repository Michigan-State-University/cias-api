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

  def body_data
    body['data']
  end

  def data_elements
    body_data&.each { |hash| yield(hash) }
  end

  def dictionary
    @dictionary ||= YAML.load_file(Rails.root.join('app/models/concerns/body_interface/guard/dictionary.yml'))
  end

  def reserved_words
    @reserved_words ||= dictionary['reserved_words']
  end

  def permitted_elements
    @permitted_elements ||= dictionary['permitted_elements']
  end

  def prevent_flood_against_body
    body&.keep_if { |k| k.eql?('data') }
  end

  def prevent_flood_against_element
    data_elements do |hash|
      hash.keep_if { |k| permitted_elements.include?(k) }
    end
  end

  def prevent_name_error_exception
    data_elements do |hash|
      hash.transform_keys! { |k| k.downcase.parameterize.underscore }
    end
  end

  def prevent_instance_exploit
    data_elements do |hash|
      hash.reject! { |k| reserved_words.include?(k) }
    end
  end

  def dismiss_empty_elements
    body_data&.delete_if { |hash| hash.empty? }
  end
end
