# frozen_string_literal: true

class V1::ProblemSerializer < V1Serializer
  attributes :name, :user_id, :sessions, :status, :shared_to
end
