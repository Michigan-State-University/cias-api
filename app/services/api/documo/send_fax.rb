# frozen_string_literal: true

class Api::Documo::SendFax
  include Rails.application.routes.url_helpers

  ENDPOINT = "#{ENV.fetch('BASE_DOCUMO_URL')}/v1/faxes/multiple"

  def self.call(fax_numbers, attachments, include_cover_page, fields, logo)
    new(fax_numbers, attachments, include_cover_page, fields, logo).call
  end

  def initialize(fax_numbers, attachments, include_cover_page, fields, logo)
    @fax_numbers = fax_numbers
    @attachments = attachments
    @include_cover_page = include_cover_page
    @fields = fields
    @logo = logo
  end

  attr_reader :fax_numbers, :attachments, :include_cover_page, :fields, :logo

  def call
    boundary = SecureRandom.hex(16)
    response = connection.post do |req|
      req.headers['Authorization'] = "Basic #{ENV.fetch('DOCUMO_API_KEY')}"
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
      [:coverPageId, ENV.fetch('DOCUMO_COVER_PAGE_ID')]
    ]

    @fax_numbers.each do |fax_number|
      data.append([:recipientFax, fax_number])
    end

    @attachments.each do |attachment|
      data.append([:attachments, attachment])
    end

    data.append([:cf, { logo: '<img src="https://picsum.photos/200"></img>' }.to_json])
    data
  end

  def build_multipart_data(boundary)
    body = form_data.each_with_object([]) do |(key, value), parts|
      parts << "--#{boundary}\r\n"
      parts << (if key.eql?(:attachments)
                  "Content-Disposition: form-data; name=\"#{key}\"; filename=\"#{value.filename}\"\r\n"
                else
                  "Content-Disposition: form-data; name=\"#{key}\"\r\n"
                end)
      parts << "\r\n"
      parts << (key.eql?(:attachments) ? "#{value.blob.download}\r\n" : "#{value}\r\n")
    end

    body << "--#{boundary}--\r\n"
    body.join
  end
end
