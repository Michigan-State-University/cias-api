# frozen_string_literal: true

class CleanJob::Blobs < CleanJob
  def perform(filenames)
    ActiveStorage::Blob.where(filename: filenames).each do |blob|
      blob.attachments.first.purge unless blob.nil?
    end
  end
end
