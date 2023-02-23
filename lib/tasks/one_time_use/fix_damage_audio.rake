# frozen_string_literal: true

namespace :audio do
  desc 'Fix all used audio'
  task recreate_corrupted_files: :environment do
    p "Scanning user sessions..."
    p  "Corrupted audios => #{Audio.left_joins(:mp3_attachment).where('active_storage_attachments.id is NULL').count}"

    user_sessions_with_corrupted_audio  =  UserSession::Classic.where(name_audio_id: Audio.left_joins(:mp3_attachment).where('active_storage_attachments.id is NULL').select(:id))
    to_fix_counter = user_sessions_with_corrupted_audio.count
    p "Found #{to_fix_counter} user sessions with corrupted audio."
    p "Start process of recreation..."

    count = 0
    user_sessions_with_corrupted_audio.each do |user_session|
      audio = user_session.name_audio
      name = user_session.answers.find_by(type: "Answer::Name").decrypted_body.dig('data', 0, 'value', 'phonetic_name')
      google_tts_voice = GoogleTtsVoice.find(user_session.session.google_tts_voice_id)
      language_code = google_tts_voice.language_code
      voice_type = google_tts_voice.voice_type

      Audio::TextToSpeech.new(audio, text: name, language: language_code, voice_type: voice_type).execute
      audio.save
      count += 1
      p "Fixed #{count}/#{to_fix_counter}"
    end

    p "All used audios are good now."
    p "Start deleting unused corrupted audios..."


    Audio.left_joins(:mp3_attachment).where('active_storage_attachments.id is NULL').destroy_all

    p "Task has just finished successfully!"
  end
end
