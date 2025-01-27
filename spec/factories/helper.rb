# frozen_string_literal: true

module FactoryHelpers
  def self.upload_file(src, content_type, binary = false)
    path = Rails.root.join(src)
    original_filename = ::File.basename(path)

    content = File.read(path)
    tempfile = Tempfile.open(original_filename)
    tempfile.write content
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile, content_type, binary, original_filename: original_filename)
  end
end
