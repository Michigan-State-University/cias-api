# frozen_string_literal: true

class Api::Documo::SendFax
  include Api::Request

  ENDPOINT = "#{ENV['BASE_DOCUMO_URL']}/v1/faxes"

  def self.call(fax_number, logo_url, pdf_file_url)
    new(fax_number, logo_url, pdf_file_url).call
  end

  def initialize(fax_number, logo_url, pdf_file_url)
    @fax_number = fax_number
    @logo_url = logo_url
    @pdf_file_url = pdf_file_url
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
    {
      faxNumber: @fax_number,
      'attachmentUrls[]': @pdf_file_url,
      coverPage: true,
      coverPageId: '9998d00d-d8d6-4d60-90c5-a022051087e0',
      cf: {
        logo: "<img src=\"#{@logo_url}\"></img>"
      }.to_json
    }
  end

  def build_multipart_data(boundary)
    body = form_data.each_with_object([]) do |(key, value), parts|
      parts << "--#{boundary}\r\n"
      parts << "Content-Disposition: form-data; name=\"#{key}\"\r\n"
      parts << "\r\n"
      parts << "#{value}\r\n"
    end

    body << "--#{boundary}--\r\n"
    body.join
  end
end
