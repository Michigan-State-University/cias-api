# frozen_string_literal: true

class V1::UserSessionSerializer < V1Serializer
  attributes :finished_at, :last_answer_at
end
