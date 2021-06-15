# frozen_string_literal: true

require 'google/cloud/translate/v2'

namespace :google_languages do
  desc 'Fetch supported languages by Google'
  task fetch: :environment do
    GoogleLanguage.delete_all

    translate = Google::Cloud::Translate::V2.new(credentials: credentials)
    languages = translate.languages 'en'

    ActiveRecord::Base.transaction do
      languages.each do |language|
        GoogleLanguage.create!(language_name: language.name, language_code: language.code)
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
end
