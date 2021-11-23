# frozen_string_literal: true

class V1::Paginate
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
    return collection if (start_index.blank? && end_index.blank?) || collection.blank?

    collection[start_index..end_index]
  end
end
