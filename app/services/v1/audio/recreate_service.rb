# frozen_string_literal: true

class V1::Audio::RecreateService
  def self.call
    new.call
  end

  def call
    UserSession.where.not(name_audio: [nil]).update_all(name_audio_id: nil)
    Audio.delete_all

    Question.find_each do |question|
      question.duplicated = true
      question.execute_narrator
      question.duplicated = false
    end
  end
end
