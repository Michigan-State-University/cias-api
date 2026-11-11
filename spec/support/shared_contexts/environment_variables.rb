# frozen_string_literal: true

# Sets environment variables for each example and restores the previous values afterwards
# (a nil value removes the variable). Nest it to override a value set by an outer context.
#
#   include_context 'with environment variables', { 'EHR_SITE_NAME' => 'Example Health' }
RSpec.shared_context 'with environment variables' do |values|
  around do |example|
    previous = values.keys.index_with { |name| ENV.fetch(name, nil) }
    values.each { |name, value| ENV[name] = value }
    example.run
  ensure
    previous&.each { |name, value| ENV[name] = value }
  end
end
