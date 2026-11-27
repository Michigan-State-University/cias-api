# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::ParticipantUploads::ModerationAdapter do
  subject(:adapter) { described_class.new }

  let(:upload) { create(:participant_upload, :clean) }
  let(:blob) { upload.file.blob }
  let(:s3_bucket) { instance_double(Aws::S3::Bucket, name: 'cias-uploads-test-bucket') }
  let(:s3_service) { double('S3Service', bucket: s3_bucket) }
  let(:rekognition) { Aws::Rekognition::Client.new(stub_responses: true, region: 'eu-west-1') }

  before do
    allow(blob).to receive(:service).and_return(s3_service)
    allow(Aws::Rekognition::Client).to receive(:new).and_return(rekognition)
  end

  def responds_with(labels:, model_version: '7.0')
    rekognition.stub_responses(:detect_moderation_labels, moderation_labels: labels, moderation_model_version: model_version)
  end

  describe 'an image the moderation model flags' do
    before do
      responds_with(labels: [{ confidence: 92.4, name: 'Violence', parent_name: '', taxonomy_level: 1 }])
    end

    it 'keeps the category name and the confidence' do
      expect(adapter.detect(blob).labels).to eq([{ 'name' => 'Violence', 'confidence' => 92.4 }])
    end

    it 'reports the model version the answer came from' do
      expect(adapter.detect(blob).model_version).to eq('7.0')
    end
  end

  describe 'a clean image' do
    before { responds_with(labels: []) }

    it 'returns no labels, which is a result and not a failure' do
      result = adapter.detect(blob)

      expect(result.labels).to eq([])
      expect(result.model_version).to eq('7.0')
    end
  end

  describe 'the detail the deeper taxonomy carries' do
    before do
      responds_with(labels: [
                      { confidence: 88.1, name: 'Drugs & Tobacco', parent_name: '', taxonomy_level: 1 },
                      { confidence: 88.1, name: 'Drugs & Tobacco Paraphernalia & Use', parent_name: 'Drugs & Tobacco', taxonomy_level: 2 },
                      { confidence: 88.1, name: 'Smoking', parent_name: 'Drugs & Tobacco Paraphernalia & Use', taxonomy_level: 3 }
                    ])
    end

    it 'keeps the top-level category and drops what is below it' do
      expect(adapter.detect(blob).labels).to eq([{ 'name' => 'Drugs & Tobacco', 'confidence' => 88.1 }])
    end
  end

  describe 'a known name arriving below the top level' do
    before do
      responds_with(labels: [
                      { confidence: 61.0, name: 'Violence', parent_name: 'Something Else', taxonomy_level: 2 }
                    ])
    end

    it 'is dropped, because only the top level is ours to store' do
      expect(adapter.detect(blob).labels).to eq([])
    end
  end

  describe 'a category outside the vocabulary we know' do
    before do
      responds_with(labels: [
                      { confidence: 70.0, name: 'Something AWS Added Later', parent_name: '', taxonomy_level: 1 },
                      { confidence: 70.0, name: 'Gambling', parent_name: '', taxonomy_level: 1 }
                    ])
    end

    it 'never reaches our records' do
      expect(adapter.detect(blob).labels).to eq([{ 'name' => 'Gambling', 'confidence' => 70.0 }])
    end
  end

  describe 'the request it sends' do
    before { responds_with(labels: []) }

    it 'points Rekognition at the object instead of shipping the bytes' do
      allow(rekognition).to receive(:detect_moderation_labels).and_call_original

      adapter.detect(blob)

      expect(rekognition).to have_received(:detect_moderation_labels).with(
        image: { s3_object: { bucket: 'cias-uploads-test-bucket', name: blob.key } },
        min_confidence: Settings.participant_uploads.moderation.min_confidence
      )
    end

    it 'never sends the name the participant gave the file' do
      allow(rekognition).to receive(:detect_moderation_labels).and_call_original

      adapter.detect(blob)

      expect(rekognition).to have_received(:detect_moderation_labels) do |params|
        expect(params.to_s).not_to include('wyniki badania')
      end
    end
  end

  describe 'a blob that does not live in S3' do
    it 'refuses instead of guessing' do
      allow(blob).to receive(:service).and_return(ActiveStorage::Blob.service)

      expect { adapter.detect(blob) }.to raise_error(described_class::UnsupportedServiceError)
    end
  end

  describe 'an error from the service' do
    it 'bubbles up so the job can retry' do
      rekognition.stub_responses(:detect_moderation_labels, 'ThrottlingException')

      expect { adapter.detect(blob) }.to raise_error(Aws::Rekognition::Errors::ThrottlingException)
    end
  end
end
