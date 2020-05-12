# frozen_string_literal: true

class QuestionSerializer
  include FastJsonapi::ObjectSerializer
  include InterfaceSerializer
  attributes :type, :intervention, :previous_id, :title, :subtitle, :body
end
