# frozen_string_literal: true

module Pagination
  include Pagy::Backend

  def paginate(collection, params)
    _, paginated_collection = pagy(collection,
                                   items: params[:per_page] || default_items(collection),
                                   page: params[:page] || 1)
    paginated_collection
  end

  private

  def default_items(collection)
    (i = collection.length) >= 1 ? i : 1
  end
end
