# frozen_string_literal: true

Oj.default_options = { mode: :rails }
Oj.optimize_rails

module ActiveSupport::JSON::Encoding
  class Oj < JSONGemEncoder
    def encode(value)
      ::Oj.dump(value.as_json)
    end
  end
end

ActiveSupport.json_encoder = ActiveSupport::JSON::Encoding::Oj
