# frozen_string_literal: true

class V1::ParticipantUploads::GuardDutyS3Adapter
  class UnsupportedServiceError < StandardError; end
  class ScanStatusUnavailableError < StandardError; end

  TAG_KEY = 'GuardDutyMalwareScanStatus'

  VERDICT_BY_TAG = {
    'NO_THREATS_FOUND' => :clean,
    'THREATS_FOUND' => :infected,
    'UNSUPPORTED' => :unreadable,
    'FAILED' => :unreadable,
    # GuardDuty could not read the object: our configuration, not the file. The upload
    # still ends here instead of waiting for a verdict that will never come, and the
    # reason says whose fault it was.
    'ACCESS_DENIED' => :scanner_misconfigured
  }.freeze

  def scan(blob)
    status = scan_status_tag(blob)
    return :pending if status.nil?

    VERDICT_BY_TAG.fetch(status) { raise ScanStatusUnavailableError, "unknown #{TAG_KEY} value: #{status}" }
  end

  private

  def scan_status_tag(blob)
    service = s3_service_for(blob)
    tagging = service.client.client.get_object_tagging(bucket: service.bucket.name, key: blob.key)
    tagging.tag_set.find { |tag| tag.key == TAG_KEY }&.value
  rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NoSuchBucket
    'FAILED'
  rescue Aws::S3::Errors::AccessDenied => e
    raise ScanStatusUnavailableError, "cannot read #{TAG_KEY}: #{e.class}"
  end

  def s3_service_for(blob)
    service = blob.service
    return service if service.respond_to?(:bucket) && service.respond_to?(:client)

    raise UnsupportedServiceError, "GuardDuty scans S3 objects, got #{service.class}"
  end
end
