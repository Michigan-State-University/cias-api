# frozen_string_literal: true

class Api::Documo::SendMultipleFaxes
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
    @logo = logo if logo&.attached?
  end

  attr_reader :fax_numbers, :attachments, :include_cover_page, :fields, :logo

  def call
    response = connection.post do |req|
      req.headers['Authorization'] = "Basic #{ENV.fetch('DOCUMO_API_KEY')}"
      req.headers['Content-Type'] = 'multipart/form-data'
      req.body = form_data
    end
    {
      status: response.status,
      body: JSON.parse(response.body)
    }
  end

  def connection
    Faraday.new(url: ENDPOINT) do |conn|
      conn.adapter :net_http
      conn.ssl.verify = true
      conn.request :url_encoded
      conn.request :multipart
    end
  end

  def form_data
    {
      coverPage: include_cover_page,
      coverPageId: ENV.fetch('DOCUMO_COVER_PAGE_ID'),
      recipientFax: fax_numbers.join(', '),
      cf: custom_fields,
      attachments: attachments.map { |file| Faraday::UploadIO.new(StringIO.new(file.download), file.content_type, file.filename.to_s) }
    }
  end

  def custom_fields
    {
      logo: logo.present? ? "<img src=\"#{logo.url}\" style=\"max-height: 200px\"></img>" : '',
      senderName: fields[:cover_letter_sender],
      subject: fields[:name],
      notes: fields[:cover_letter_description],
      recipientName: fields[:receiver]
    }
  end
end
