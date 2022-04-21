class FetchGoogleTts < ActiveRecord::Migration[6.0]
  def change
    Rake::Task['google_tts_languages:fetch'].invoke unless GoogleTtsLanguage.exists? && GoogleTtsVoice.exists?
  end
end
