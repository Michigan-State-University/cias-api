# frozen_string_literal: true

class Api::Documo::SendFax
  include Api::Request

  ENDPOINT = "#{ENV['BASE_DOCUMO_URL']}/v1/faxes"

  def self.call(fax_number, logo_url, attachments)
    new(fax_number, logo_url, attachments).call
  end

  def initialize(fax_number, logo_url, attachments)
    @fax_number = fax_number
    @logo_url = logo_url
    @attachments = attachments
  end

  def call
    boundary = SecureRandom.hex(16)
    response = connection.post do |req|
      req.headers['Authorization'] = "Basic #{ENV['DOCUMO_API_KEY']}"
      req.headers['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      req.body = build_multipart_data(boundary)
    end
    JSON.parse(response.body)
  end

  private

  def connection
    Faraday.new(url: ENDPOINT) do |conn|
      conn.adapter Faraday.default_adapter
      conn.ssl.verify = true
    end
  end

  def form_data
    data = [
      [:faxNumber, @fax_number],
      [:coverPage, true],
      [:coverPageId, '9998d00d-d8d6-4d60-90c5-a022051087e0'],
      [:cf, {
        logo: "<img src=\"#{@logo_url}\"></img>"
      }.to_json]
    ]

    @attachments.each do |attachment|
      data.append([
                    :attachments,
                    Faraday::UploadIO.new(StringIO.new(attachment.download), attachment.content_type)
                  ])
    end
    data
  end

  def build_multipart_data(boundary)
    body = form_data.each_with_object([]) do |(key, value), parts|
      parts << "--#{boundary}\r\n"
      if value.is_a?(Faraday::UploadIO)
        parts << "Content-Disposition: form-data; name=\"#{key}\"; filename=\"report.pdf\"\r\n"
        parts << "Content-Type: #{value.content_type}\r\n"
        parts << "\r\n"
        parts << "#{value.read}\r\n"
      else
        parts << "Content-Disposition: form-data; name=\"#{key}\"\r\n"
        parts << "\r\n"
        parts << "#{value}\r\n"
      end
    end

    body << "--#{boundary}--\r\n"
    body.join
  end
end
