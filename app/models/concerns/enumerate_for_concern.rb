# frozen_string_literal: true

class MultipleInclusionValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value, *_aaa)
    return true if allow_blank?(value)
    return true if allow_nil?(value)

    record.errors.add attribute, (options[:message] || :inclusion) unless include?(value)
  end

  def allow_blank?(value)
    options[:allow_blank] && value.blank?
  end

  def allow_nil?(value)
    options[:allow_nil] && value.nil?
  end

  def include?(value)
    value.present? && options[:in].to_set.superset?(value.to_set)
  end
end

module EnumerateForConcern
  extend ActiveSupport::Concern

  module ClassMethods
    def enumerate_for(field, values, as_like: nil, multiple: false, **options)
      as_like ||= field
      validator = multiple ? :multiple_inclusion : :inclusion
      validates as_like, validator => options.merge(in: values)

      define_singleton_method(as_like.to_s.pluralize) do
        values
      end

      define_method("#{field}=") do |value|
        value = value.compact_blank if value && multiple
        self[field] = value
      end

      return unless as_like != field

      alias_method "#{as_like}=", "#{field}="
      alias_method as_like, field
    end
  end
end
