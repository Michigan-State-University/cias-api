# frozen_string_literal: true

module BodyInterface::Guard
  def guard_protection
    prevent_name_error_exception
    prevent_instance_exploit
  end

  private

  def prevent_name_error_exception
    body&.transform_keys! { |k| k.downcase.parameterize.underscore }
  end

  def reserved_words
    @reserved_words ||= YAML.load_file(Rails.root.join('app/models/concerns/body_interface/dictionary.yml'))['reserved_words']
  end

  def prevent_instance_exploit
    body&.reject! { |k| reserved_words.include?(k) }
  end
end
