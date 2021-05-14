# frozen_string_literal: true

Oj.default_options = { mode: :rails }
Oj.optimize_rails

class ActiveSupport::JSON::Encoding::Oj < JSONGemEncoder
  def encode(value)
    ::Oj.dump(value.as_json)
  end
end

ActiveSupport.json_encoder = ActiveSupport::JSON::Encoding::Oj
