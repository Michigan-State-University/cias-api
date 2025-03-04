# frozen_string_literal: true

class Api::CatMh::CheckStatus
  include Api::Request

  attr_reader :application_id, :organization_id, :interview_id, :identifier, :signature

  ENDPOINT = "#{ENV.fetch('BASE_CAT_URL', nil)}/portal/secure/interview/status".freeze

  def self.call(interview_id, identifier, signature, application_id, organization_id)
    new(interview_id, identifier, signature, application_id, organization_id).call
  end

  def initialize(interview_id, identifier, signature, application_id, organization_id)
    @application_id = application_id
    @organization_id = organization_id
    @identifier = identifier
    @interview_id = interview_id
    @signature = signature
  end

  def call
    result = request(:post, ENDPOINT, params)
    response(result)
  end

  private

  def client
    @client = Faraday.new(ENDPOINT) do |client|
      client.request :url_encoded
      client.adapter Faraday.default_adapter
      client.headers['applicationid'] = application_id
      client.headers['Content-Type'] = 'application/json'
    end
  end

  def params
    {
      'organizationID' => organization_id,
      'interviewID' => interview_id,
      'identifier' => identifier,
      'signature' => signature
    }.to_json
  end
end
