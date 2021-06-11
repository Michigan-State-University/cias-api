# frozen_string_literal: true

require 'google/cloud/translate/v2'

namespace :google_languages do
  desc 'Fetch supported languages by Google'
  task fetch: :environment do
    GoogleLanguage.delete_all

    translate = Google::Cloud::Translate::V2.new
    languages = translate.languages 'en'

    ActiveRecord::Base.transaction do
      languages.each do |language|
        GoogleLanguage.create!(language_name: language.name, language_code: language.code)
      end
    end
  end
end
