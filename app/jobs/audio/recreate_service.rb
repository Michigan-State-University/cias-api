# frozen_string_literal: true

class Audio::RecreateService < ApplicationJob
  queue_as :default

  def perform
    UserSession.where.not(name_audio: [nil]).update_all(name_audio_id: nil)
    Audio.delete_all

    Question.find_each do |question|
      question.duplicated = true
      question.execute_narrator
      question.duplicated = false
    end
  end
end
