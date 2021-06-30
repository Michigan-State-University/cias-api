# frozen_string_literal: true

require 'metainspector'

class V1::ExternalLinksController < V1Controller
  def show_website_metadata
    head :expectation_failed and return unless url

    page = MetaInspector.new(url)
    head :not_found and return if page.document[0].eql?(NOT_EXISTING_URL_ERROR)

    is_scraping_exception = page.document[0].eql?(SCRAPING_EXCEPTION)

    metadata =
      {
        url: page.url,
        title: page.title,
        description: is_scraping_exception ? '' : page.description,
        image: is_scraping_exception ? '' : page.image,
        images: is_scraping_exception ? [] : page.images,
        hash_metadata: is_scraping_exception ? '' : page.to_hash,
        parsed_document: is_scraping_exception ? '' : page.parsed_document
      }

    render json: metadata
  end

  private

  NOT_EXISTING_URL_ERROR = 'Socket error: The url provided does not exist or is temporarily unavailable'
  SCRAPING_EXCEPTION = 'Scraping exception: 503 Service Unavailable'

  def url
    params[:url]
  end
end
