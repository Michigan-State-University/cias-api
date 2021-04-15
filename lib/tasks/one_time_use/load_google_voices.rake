# frozen_string_literal: true

namespace :google_tts_languages do
  desc 'Fetch google tts'
  task fetch: :environment do
    GoogleTtsLanguage.delete_all
    GoogleTtsVoice.delete_all
    text_to_speech_client = Google::Cloud::TextToSpeech.text_to_speech do |tts|
      tts.credentials = credentials
    end
    voices = text_to_speech_client.list_voices({}).voices
    hash = {}
    voices.each do |voice|
      hash[voice.language_codes[0]] = hash[voice.language_codes[0]] ? hash[voice.language_codes[0]] << voice : [voice]
    end
    languages_hash = prepare_languages_hash
    ActiveRecord::Base.transaction do
      hash.each do |language, voices|
        language_name = prepare_language_name(language, languages_hash)
        tts_language = GoogleTtsLanguage.create!(language_name: language_name)

        usage_hash = {
          'standard-male' => 1,
          'standard-female' => 1,
          'wavenet-male' => 1,
          'wavenet-female' => 1
        }
        voices.each do |voice_type|
          voice_standard = voice_type.name.split('-')[2].downcase
          voice_gender = voice_type.ssml_gender.to_s.downcase
          voice_hash = "#{voice_standard}-#{voice_gender}"
          voice_name = "#{voice_hash}-#{usage_hash[voice_hash]}"
          usage_hash[voice_hash] += 1

          GoogleTtsVoice.create!(
            voice_label: voice_name.capitalize,
            voice_type: voice_type.name,
            language_code: language,
            google_tts_language: tts_language
          )
        end
      end
    end
  end

  def credentials
    if Rails.env.development?
      Oj.load_file(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
    else
      Oj.load(ENV['GOOGLE_APPLICATION_CREDENTIALS'])
    end
  rescue Oj::ParseError
    ENV['GOOGLE_APPLICATION_CREDENTIALS']
  end

  def prepare_language_name(language, languages_hash)
    language_code = language.split('-')[0]
    country_code = language.split('-')[1]
    full_language_name = languages_hash[language_code]
    country = ISO3166::Country[country_code]
    return full_language_name if country.nil?

    country_name = country.unofficial_names[0]
    "#{full_language_name} (#{country_name})"
  end

  def prepare_languages_hash
    {
      'ar' => 'Arabic',
      'bn' => 'Bengali',
      'en' => 'English',
      'fr' => 'French',
      'es' => 'Spanish',
      'fi' => 'Finnish',
      'gu' => 'Gujarati',
      'ja' => 'Japanese',
      'kn' => 'Kannada',
      'ml' => 'Malayalam',
      'sv' => 'Swedish',
      'ta' => 'Tamil',
      'tr' => 'Turkish',
      'cs' => 'Czech',
      'de' => 'German',
      'hi' => 'Hindi',
      'id' => 'Indonesian',
      'it' => 'Italian',
      'ko' => 'Korean',
      'ru' => 'Russian',
      'uk' => 'Ukrainian',
      'cmn' => 'Mandarin',
      'da' => 'Danish',
      'el' => 'Greek',
      'fil' => 'Filipino',
      'hu' => 'Hungarian',
      'nb' => 'Norwegian',
      'nl' => 'Dutch',
      'pt' => 'Portuguese',
      'sk' => 'Slovak',
      'vi' => 'Vietnamese',
      'pl' => 'Polish',
      'yue' => 'Chinese',
      'ca' => 'Catalan',
      'af' => 'Afrikaans',
      'bg' => 'Bulgarian',
      'lv' => 'Latvian',
      'ro' => 'Romanian',
      'sr' => 'Serbian',
      'th' => 'Thai',
      'te' => 'Telugu',
      'is' => 'Icelandic'
    }
  end
end
