# frozen_string_literal: true

class V1::AuthController
  %w[Confirmations Registrations].each do |klass|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
     class #{klass}Controller < DeviseTokenAuth::#{klass}Controller
        include Resource
        prepend Auth::Default
      end
    RUBY
  end
end
