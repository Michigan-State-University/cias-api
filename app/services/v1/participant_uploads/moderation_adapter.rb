# frozen_string_literal: true

class V1::ParticipantUploads::ModerationAdapter
  class UnsupportedServiceError < StandardError; end

  TOP_LEVEL = 1
  MAX_IMAGE_BYTES = 15.megabytes

  Result = Struct.new(:labels, :model_version, keyword_init: true)

  def detect(blob)
    service = s3_service_for(blob)
    response = client.detect_moderation_labels(
      image: { s3_object: { bucket: service.bucket.name, name: blob.key } },
      min_confidence: Settings.participant_uploads.moderation.min_confidence
    )

    Result.new(labels: top_level_labels(response), model_version: response.moderation_model_version)
  end

  private

  def top_level_labels(response)
    response.moderation_labels
            .select { |label| label.taxonomy_level == TOP_LEVEL }
            .select { |label| label.name.in?(ParticipantUpload::MODERATION_CATEGORIES) }
            .map { |label| { 'name' => label.name, 'confidence' => label.confidence.round(1) } }
            .uniq { |label| label['name'] }
  end

  def client
    @client ||= Aws::Rekognition::Client.new(region: region)
  end

  def region
    ENV.fetch('REKOGNITION_REGION') { ENV.fetch('STORAGE_REGION', nil) }
  end

  def s3_service_for(blob)
    service = blob.service
    return service if service.respond_to?(:bucket)

    raise UnsupportedServiceError, "Rekognition reads S3 objects, got #{service.class}"
  end
end
