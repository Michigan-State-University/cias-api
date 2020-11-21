# frozen_string_literal: true

# Due to somewhat confusing behavior of the `config` gem,
# this file is loaded BEFORE config/application.rb and BEFORE all other initializers in this
# directory. The `Settings` constant only becomes available AFTER this file has been parsed.
#
# See: lib/config/integrations/rails/railtie.rb

require 'rake' # to make `Rake.application` work

Config.setup do |config|
  config.use_env = true
  config.env_prefix = 'CIAS'
  config.env_separator = '__'
  config.env_converter = :downcase
  config.env_parse_values = true
  config.fail_on_missing = true
end
