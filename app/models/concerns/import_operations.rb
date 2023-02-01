# frozen_string_literal: true

module ImportOperations
  def get_import_service_class(object_hash, model_source)
    "Import::V#{object_hash[:version]}::#{model_source.name}Service".safe_constantize
  end

  def import_file(img)
    return if img.blank?

    {
      io: StringIO.new(Base64.decode64(img[:file])),
      content_type: img[:content_type],
      filename: "#{SecureRandom.hex}.#{img[:extension]}"
    }
  end
end
