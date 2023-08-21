# frozen_string_literal: true

class Api::Documo::SendMultipleFaxes
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
    response = connection.post do |req|
      req.headers['Authorization'] = "Basic #{ENV.fetch('DOCUMO_API_KEY')}"
      req.headers['Content-Type'] = "multipart/form-data"
      req.body = form_data
    end
    JSON.parse(response.body)
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
    # files.map{ |file| Faraday::UploadIO.new(file[0], file[1]) }

    # avatar_data = user.avatar.download

    # Create a Faraday::UploadIO object
    # avatar_upload_io = Faraday::UploadIO.new(StringIO.new(avatar_data), user.avatar.content_type, user.avatar.filename.to_s)

    {
      coverPage: @include_cover_page,
      coverPageId: ENV.fetch('DOCUMO_COVER_PAGE_ID'),
      recipientFax: fax_numbers.first,
      cf: { logo: '<img src="https://picsum.photos/200"></img>' },
      attachments: attachments.map{ |file| Faraday::UploadIO.new(StringIO.new(file.download), file.content_type, file.filename.to_s) },
    }
  end
end
