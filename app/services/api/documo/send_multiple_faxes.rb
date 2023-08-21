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
    # boundary = SecureRandom.hex(16)
    response = connection.post do |req|
      req.headers['Authorization'] = "Basic #{ENV.fetch('DOCUMO_API_KEY')}"
      req.headers['Content-Type'] = "multipart/form-data"
      req.body = form_data
    end
    JSON.parse(response.body)
  end

  def connection
    Faraday.new(url: ENDPOINT) do |conn|
      conn.adapter Faraday.default_adapter
      conn.ssl.verify = true
      conn.request :multipart
    end
  end

  def form_data
    # data = [
    #   [:coverPage, @include_cover_page],
    #   [:coverPageId, ENV.fetch('DOCUMO_COVER_PAGE_ID')]
    # ]
    #
    # @fax_numbers.each do |fax_number|
    #   data.append([:recipientFax, fax_number])
    # end
    #
    # @attachments.each do |attachment|
    #   data.append([:attachments, attachment.download])
    # end
    #
    # data.append([:cf, { logo: '<img src="https://picsum.photos/200"></img>' }.to_json])
    # data
    {
      coverPage: @include_cover_page,
      coverPageId: ENV.fetch('DOCUMO_COVER_PAGE_ID'),
      recipientFax: fax_numbers,
      attachments: attachments.map(&:download),
      cf: { logo: '<img src="https://picsum.photos/200"></img>' }
    }
  end
end
