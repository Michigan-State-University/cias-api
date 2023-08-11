# frozen_string_literal: true

class Api::Documo::SendFax
  include Api::Request
  include Rails.application.routes.url_helpers

  ENDPOINT = "#{ENV['BASE_DOCUMO_URL']}/v1/faxes/multiple"

  def self.call(fax_number, attachments, include_cover_page, fields, logo)
    new(fax_number, attachments, include_cover_page, fields, logo).call
  end

  def initialize(fax_numbers, attachments, include_cover_page, fields, logo)
    @fax_numbers = fax_numbers
    @attachments = attachments
    @include_cover_page = include_cover_page
    @fields = fields
    @logo = logo
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
      [:coverPage, @include_cover_page],
      [:coverPageId, '9998d00d-d8d6-4d60-90c5-a022051087e0']
    ]

    @fax_numbers.each do |fax_number|
      data.append([:recipientFax, fax_number])
    end

    @attachments.each do |attachment|
      data.append([:attachmentUrls, polymorphic_url(attachment)])
    end

    fields[:logo] = "<img src=\"#{polymorphic_url(@logo)}\"></img>" unless @logo.nil?

    data.append(fields)
    data
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
