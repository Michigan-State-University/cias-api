# frozen_string_literal: true

class Api::Hl7Receiver::Authentication
  include Api::Hl7Receiver::TlsErrorReporter

  def self.call
    new.call
  end

  def call
    connection = Faraday.new endpoint, ssl: Api::Hl7Receiver::SslOptions.call

    response = connection.post do |request|
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(params)
    end

    JSON.parse(response.body).symbolize_keys if response.status == 200
  rescue Faraday::SSLError => e
    report_tls_error(e, endpoint)
    raise
  end

  private

  def endpoint
    Ehr::Settings.fetch!('HL7_RECEIVER_TOKEN_URL')
  end

  def params
    {
      grant_type: 'password',
      username: Ehr::Settings.fetch('HL7_RECEIVER_USERNAME'),
      client_id: Ehr::Settings.fetch('HL7_RECEIVER_CLIENT_ID'),
      client_secret: Ehr::Settings.fetch('HL7_RECEIVER_CLIENT_SECRET'),
      password: Ehr::Settings.fetch('HL7_RECEIVER_PASSWORD')
    }
  end
end
