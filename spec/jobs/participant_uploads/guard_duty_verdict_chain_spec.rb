# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GuardDuty verdict chain', type: :job do
  include ActiveJob::TestHelper

  documented_results = {
    'NO_THREATS_FOUND' => {
      'detail-type' => 'GuardDuty Malware Protection Object Scan Result',
      'source' => 'aws.guardduty',
      'detail' => {
        'scanStatus' => 'COMPLETED',
        'resourceType' => 'S3_OBJECT',
        'scanResultDetails' => { 'scanResultStatus' => 'NO_THREATS_FOUND', 'threats' => nil, 'statusReasons' => nil }
      }
    },
    'THREATS_FOUND' => {
      'detail-type' => 'GuardDuty Malware Protection Object Scan Result',
      'source' => 'aws.guardduty',
      'detail' => {
        'scanStatus' => 'COMPLETED',
        'resourceType' => 'S3_OBJECT',
        'scanResultDetails' => {
          'scanResultStatus' => 'THREATS_FOUND',
          'threats' => [{ 'name' => 'EICAR-Test-File (not a virus)', 'source' => 'AMAZON' }],
          'statusReasons' => nil
        }
      }
    },
    'UNSUPPORTED' => {
      'detail-type' => 'GuardDuty Malware Protection Object Scan Result',
      'source' => 'aws.guardduty',
      'detail' => {
        'scanStatus' => 'SKIPPED',
        'resourceType' => 'S3_OBJECT',
        'scanResultDetails' => { 'scanResultStatus' => 'UNSUPPORTED', 'threats' => nil, 'statusReasons' => ['PASSWORD_PROTECTED'] }
      }
    },
    'ACCESS_DENIED' => {
      'detail-type' => 'GuardDuty Malware Protection Object Scan Result',
      'source' => 'aws.guardduty',
      'detail' => {
        'scanStatus' => 'SKIPPED',
        'resourceType' => 'S3_OBJECT',
        'scanResultDetails' => { 'scanResultStatus' => 'ACCESS_DENIED', 'threats' => nil, 'statusReasons' => ['UNAUTHORIZED_TO_GET_OBJECT'] }
      }
    },
    'FAILED' => {
      'detail-type' => 'GuardDuty Malware Protection Object Scan Result',
      'source' => 'aws.guardduty',
      'detail' => {
        'scanStatus' => 'FAILED',
        'resourceType' => 'S3_OBJECT',
        'scanResultDetails' => { 'scanResultStatus' => 'FAILED', 'threats' => nil, 'statusReasons' => nil }
      }
    }
  }.freeze

  outcomes = {
    'NO_THREATS_FOUND' => { scan_status: 'clean', deletion_reason: nil, attached: true },
    'THREATS_FOUND' => { scan_status: 'deleted', deletion_reason: 'MALWARE_DETECTED', attached: false },
    'UNSUPPORTED' => { scan_status: 'deleted', deletion_reason: 'SCANNER_CANNOT_INSPECT', attached: false },
    'FAILED' => { scan_status: 'deleted', deletion_reason: 'SCANNER_CANNOT_INSPECT', attached: false },
    'ACCESS_DENIED' => { scan_status: 'deleted', deletion_reason: 'SCANNER_CONFIGURATION_ERROR', attached: false }
  }.freeze

  subject(:upload) { create(:participant_upload) }

  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_resource) { instance_double(Aws::S3::Resource, client: s3_client) }
  let(:s3_bucket) { instance_double(Aws::S3::Bucket, name: 'cias-uploads-test-bucket') }
  let(:s3_service) { double('S3Service', client: s3_resource, bucket: s3_bucket) }

  before do
    upload
    allow(Sentry).to receive(:capture_message)
    allow(Sentry).to receive(:capture_exception)
    allow(s3_service).to receive(:delete)
    allow(s3_service).to receive(:delete_prefixed)
    allow_any_instance_of(ActiveStorage::Blob).to receive(:service).and_return(s3_service)
  end

  def object_tagged_with(value)
    tag_set = value.nil? ? [] : [instance_double(Aws::S3::Types::Tag, key: V1::ParticipantUploads::GuardDutyS3Adapter::TAG_KEY, value: value)]
    allow(s3_client).to receive(:get_object_tagging)
      .and_return(instance_double(Aws::S3::Types::GetObjectTaggingOutput, tag_set: tag_set))
  end

  def tag_value_from(event)
    event.dig('detail', 'scanResultDetails', 'scanResultStatus')
  end

  describe 'every status AWS documents ends in a defined state' do
    documented_results.each do |status, event|
      expected = outcomes.fetch(status)

      title = [expected[:scan_status], expected[:deletion_reason]].compact.join(' / ')

      it "turns #{status} into #{title}" do
        object_tagged_with(tag_value_from(event))

        perform_enqueued_jobs { ParticipantUploads::ScanJob.perform_now(upload.id) }
        upload.reload

        expect(upload.scan_status).to eq(expected[:scan_status])
        expect(upload.deletion_reason).to eq(expected[:deletion_reason])
        expect(upload.file.attached?).to eq(expected[:attached])
      end
    end

    it 'covers exactly the statuses the adapter knows, with no gap either way' do
      expect(documented_results.keys).to match_array(V1::ParticipantUploads::GuardDutyS3Adapter::VERDICT_BY_TAG.keys)
    end

    it 'serves the file only after NO_THREATS_FOUND' do
      servable = documented_results.keys.select do |status|
        outcomes.fetch(status)[:scan_status] == 'clean'
      end

      expect(servable).to eq(['NO_THREATS_FOUND'])
    end
  end

  describe 'while GuardDuty has not tagged the object yet' do
    it 'keeps the upload pending and the file in place' do
      object_tagged_with(nil)

      ParticipantUploads::ScanJob.perform_now(upload.id)
      upload.reload

      expect(upload.scan_status).to eq('pending')
      expect(upload.file).to be_attached
    end

    it 'asks again instead of giving a verdict' do
      object_tagged_with(nil)

      expect { ParticipantUploads::ScanJob.perform_now(upload.id) }
        .to have_enqueued_job(ParticipantUploads::ScanJob).with(upload.id)
    end
  end

  describe 'a status outside the documented set' do
    it 'ends as our configuration fault, never as a verdict on the file' do
      object_tagged_with('SOMETHING_AWS_ADDED_LATER')

      perform_enqueued_jobs do
        ParticipantUploads::ScanJob.perform_now(upload.id)
      rescue V1::ParticipantUploads::GuardDutyS3Adapter::ScanStatusUnavailableError
        nil
      end
      upload.reload

      expect(upload.scan_status).not_to eq('clean')
    end
  end

  describe 'the threat name AWS reports' do
    it 'never reaches the participant upload record' do
      object_tagged_with(tag_value_from(documented_results.fetch('THREATS_FOUND')))

      perform_enqueued_jobs { ParticipantUploads::ScanJob.perform_now(upload.id) }

      expect(upload.reload.deletion_reason).to eq('MALWARE_DETECTED')
      expect(upload.attributes.values.map(&:to_s).join(' ')).not_to include('EICAR')
    end
  end
end
