# frozen_string_literal: true

class V1::AnswerSerializer < V1Serializer
  attributes :type, :decrypted_body, :question_id, :next_session_id

  attribute :participant_uploads, if: proc { |record| record.is_a?(Answer::FileUpload) } do |object|
    V1::ParticipantUploadSerializer.new(object.participant_uploads).serializable_hash[:data].map do |upload|
      upload[:attributes].merge(id: upload[:id])
    end
  end
end
