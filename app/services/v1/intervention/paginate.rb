# frozen_string_literal: true

class V1::Intervention::Paginate
  attr_reader :collection, :start_index, :end_index

  def self.call(collection, start_index, end_index)
    new(collection, start_index, end_index).call
  end

  def initialize(collection, start_index, end_index)
    @collection = collection
    @start_index = start_index
    @end_index = end_index
  end

  def call
    return collection if start_index.blank? && end_index.blank?

    collection&.indexing(paginated_collection_ids)
  end

  def end_index_or_last_index
    return collection.size - 1 if end_index >= collection.size

    end_index
  end

  def paginated_collection_ids
    collection[start_index..end_index_or_last_index]&.pluck('id')
  end
end
