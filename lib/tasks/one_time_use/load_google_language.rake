# frozen_string_literal: true

require 'google/cloud/translate/v2'

namespace :google_languages do
  desc 'Fetch supported languages by Google'
  task fetch: :environment do
    AuxiliaryGoogleLanguage.delete_all

    translate = Google::Cloud::Translate::V2.new(credentials: credentials)
    languages = translate.languages 'en'

    # Only keep languages that match dev/production environment (111 languages)
    # This exact list is based on the google_languages table from dev
    commonly_used_codes = %w[
      af sq am ar hy az eu be bn bs bg ca ceb ny zh-CN zh-TW co hr cs da nl en eo et
      tl fi fr fy gl ka de el gu ht ha haw iw hi hmn hu is ig id ga it ja jw kn kk
      km rw ko ku ky lo la lv lt lb mk mg ms ml mt mi mr mn my ne no or ps fa pl pt
      pa ro ru sm gd sr st sn sd si sk sl so es su sw sv tg ta tt te th tr tk uk ur
      ug uz vi cy xh yi yo zu he zh
    ]

    p 'Starting to fetch google languages...'
    p "Fetching only commonly used languages (#{commonly_used_codes.length} languages)"

    ActiveRecord::Base.transaction do
      languages.each do |language|
        next unless commonly_used_codes.include?(language.code)
        
        AuxiliaryGoogleLanguage.create!(language_name: language.name, language_code: language.code)
        p "Created #{language.name}"
      end
    end

    p "Finished fetch google languages successfully! (#{AuxiliaryGoogleLanguage.count} languages created)"
  end

  class AuxiliaryGoogleLanguage < ActiveRecord::Base
    self.table_name = 'google_languages'
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
