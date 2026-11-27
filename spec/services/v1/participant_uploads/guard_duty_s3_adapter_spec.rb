# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::ParticipantUploads::GuardDutyS3Adapter do
  subject(:adapter) { described_class.new }

  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_resource) { instance_double(Aws::S3::Resource, client: s3_client) }
  let(:s3_bucket) { instance_double(Aws::S3::Bucket, name: 'cias-test-bucket') }
  let(:s3_service) { double('S3Service', client: s3_resource, bucket: s3_bucket) }
  let(:blob) { create(:participant_upload).file.blob }

  before { allow(blob).to receive(:service).and_return(s3_service) }

  def tagged(status)
    tag_set = status.nil? ? [] : [instance_double(Aws::S3::Types::Tag, key: described_class::TAG_KEY, value: status)]
    allow(s3_client).to receive(:get_object_tagging).and_return(instance_double(Aws::S3::Types::GetObjectTaggingOutput, tag_set: tag_set))
  end

  describe '#scan' do
    it 'takes the bucket and the credentials from the blob own storage service' do
      tagged('NO_THREATS_FOUND')

      adapter.scan(blob)

      expect(s3_client).to have_received(:get_object_tagging).with(bucket: 'cias-test-bucket', key: blob.key)
    end

    it 'maps NO_THREATS_FOUND to clean' do
      tagged('NO_THREATS_FOUND')

      expect(adapter.scan(blob)).to eq(:clean)
    end

    it 'maps THREATS_FOUND to infected' do
      tagged('THREATS_FOUND')

      expect(adapter.scan(blob)).to eq(:infected)
    end

    %w[UNSUPPORTED FAILED].each do |status|
      it "treats #{status} as unreadable, never as clean" do
        tagged(status)

        expect(adapter.scan(blob)).to eq(:unreadable)
      end
    end

    it 'ends ACCESS_DENIED as our configuration fault, never as a verdict on the file' do
      tagged('ACCESS_DENIED')

      expect(adapter.scan(blob)).to eq(:scanner_misconfigured)
    end

    it 'raises when the role cannot read object tags' do
      allow(s3_client).to receive(:get_object_tagging).and_raise(Aws::S3::Errors::AccessDenied.new(nil, 'no tags'))

      expect { adapter.scan(blob) }.to raise_error(described_class::ScanStatusUnavailableError)
    end

    it 'reports pending while the tag is not there yet' do
      tagged(nil)

      expect(adapter.scan(blob)).to eq(:pending)
    end

    it 'raises on an unknown status instead of rejecting the file on a guess' do
      tagged('SOMETHING_NEW')

      expect { adapter.scan(blob) }.to raise_error(described_class::ScanStatusUnavailableError, /SOMETHING_NEW/)
    end

    it 'treats a missing object as unreadable' do
      allow(s3_client).to receive(:get_object_tagging).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'gone'))

      expect(adapter.scan(blob)).to eq(:unreadable)
    end

    it 'lets a transient S3 error bubble up so the job can retry' do
      allow(s3_client).to receive(:get_object_tagging).and_raise(Aws::S3::Errors::ServiceUnavailable.new(nil, 'later'))

      expect { adapter.scan(blob) }.to raise_error(Aws::S3::Errors::ServiceUnavailable)
    end

    it 'refuses to guess when the blob is not stored in S3' do
      allow(blob).to receive(:service).and_return(ActiveStorage::Blob.service)

      expect(ActiveStorage::Blob.service).not_to respond_to(:bucket)
      expect { adapter.scan(blob) }.to raise_error(described_class::UnsupportedServiceError)
    end
  end
end
