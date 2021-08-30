# frozen_string_literal: true

class Api::CatMh::CreateInterview
  include Api::Request

  attr_reader :application_id, :organization_id, :subject_id, :number_of_interventions, :tests, :language

  ENDPOINT = "#{ENV['BASE_CAT_URL']}/portal/secure/interview/createInterview"

  def self.call(subject_id, number_of_interventions, tests, language)
    new(subject_id, number_of_interventions, tests, language).call
  end

  def initialize(subject_id, number_of_interventions, tests, language)
    @subject_id = subject_id
    @number_of_interventions = number_of_interventions
    @tests = tests
    @language = language
    @application_id = ENV['APPLICATION_ID']
    @organization_id = ENV['ORGANIZATION_ID']
  end

  def call
    result = request(:post, ENDPOINT, params)
    response(result)
  end

  private

  def client
    @client ||= Faraday.new(ENDPOINT) do |client|
      client.request :url_encoded
      client.adapter Faraday.default_adapter
      client.headers['applicationid'] = application_id
      client.headers['Content-Type'] = 'application/json'
    end
  end

  def params
    {
      'organizationID' => organization_id,
      'userFirstName' => 'Automated',
      'userLastName' => 'Creation',
      'subjectID' => subject_id,
      'numberOfInterviews' => number_of_interventions,
      'language' => language,
      'tests' => tests
    }.to_json
  end
end
