# frozen_string_literal: true

require 'metainspector'

class V1::ExternalLinksController < V1Controller
  def show_website_metadata
    head :expectation_failed and return unless url

    begin
      metadata =
        {
          url: page.url,
          title: page.title,
          description: page.description,
          image: page.images.best,
          images: page.images,
          hash_metadata: page.to_hash
        }
    rescue MetaInspector::ParserError, MetaInspector::RequestError
      head :unprocessable_entity
    else
      render json: metadata
    end
  end

  private

  def url
    params[:url]
  end

  def page
    @page ||= MetaInspector.new(url)
  end
end
