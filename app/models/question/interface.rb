# frozen_string_literal: true

module Question::Interface
  extend ActiveSupport::Concern

  included { :body_attrs }

  def body_attrs
    body.each do |key, value|
      instance_variable_set("@#{key}", value)
      self.class.send(:attr_reader, key)
    end
  end
end
