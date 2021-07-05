# frozen_string_literal: true

require 'google/cloud/translate/v2'

class V1::Translation
  attr_reader :text, :from, :to

  def initialize(text, from, to)
    @text = text
    @from = from
    @to = to
  end

  def self.call(text, from, to)
    new(text, from, to).translate
  end

  def translate
    client.translate(text, from: from, to: to).text
  end

  private

  def client
    @client ||= Google::Cloud::Translate::V2.new(credentials: credentials)
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
