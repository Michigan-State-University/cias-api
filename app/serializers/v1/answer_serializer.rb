# frozen_string_literal: true

class V1::AnswerSerializer < V1Serializer
  attributes :type, :decrypted_body, :question_id, :next_session_id
end
