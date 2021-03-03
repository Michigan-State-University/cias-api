# frozen_string_literal: true

RSpec::Matchers.define :variant_with_content do |content|
  match { |variant| variant.content.match(content).present? }
end
