# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParticipantUploads::ModerationJob, type: :job do
  include ActiveJob::TestHelper

  let(:upload) { create(:participant_upload, :clean) }
  let(:adapter) { instance_double(V1::ParticipantUploads::ModerationAdapter) }
  let(:flagged) do
    V1::ParticipantUploads::ModerationAdapter::Result.new(
      labels: [{ 'name' => 'Violence', 'confidence' => 92.4 }], model_version: '7.0'
    )
  end
  let(:nothing_found) do
    V1::ParticipantUploads::ModerationAdapter::Result.new(labels: [], model_version: '7.0')
  end

  before do
    allow(Sentry).to receive(:capture_exception)
    allow(V1::ParticipantUploads::ModerationAdapter).to receive(:new).and_return(adapter)
  end

  context 'when the model flags the image' do
    before { allow(adapter).to receive(:detect).and_return(flagged) }

    it 'records the categories, the model version and the time' do
      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.moderation_status).to eq('completed')
      expect(upload.moderation_labels).to eq([{ 'name' => 'Violence', 'confidence' => 92.4 }])
      expect(upload.moderation_model_version).to eq('7.0')
      expect(upload.moderated_at).to be_present
    end

    it 'leaves the file alone, because moderation does not act on it' do
      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.scan_status).to eq('clean')
      expect(upload.file).to be_attached
      expect(upload.deletion_reason).to be_nil
    end
  end

  context 'when the model finds nothing' do
    before { allow(adapter).to receive(:detect).and_return(nothing_found) }

    it 'says checked with no labels, which is not the same as unchecked' do
      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.moderation_status).to eq('completed')
      expect(upload.moderation_labels).to eq([])
      expect(upload.moderation_skip_reason).to be_nil
    end
  end

  context 'when the file is not an image Rekognition reads' do
    let(:upload) { create(:participant_upload, :clean, content_type_detected: 'application/pdf') }

    it 'skips it with a reason instead of calling the service' do
      allow(adapter).to receive(:detect)

      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.moderation_status).to eq('skipped')
      expect(upload.moderation_skip_reason).to eq('UNSUPPORTED_FORMAT')
      expect(adapter).not_to have_received(:detect)
    end
  end

  context 'when the image is larger than the service accepts' do
    let(:upload) do
      create(:participant_upload, :clean,
             byte_size: V1::ParticipantUploads::ModerationAdapter::MAX_IMAGE_BYTES + 1)
    end

    it 'skips it with a reason instead of calling the service' do
      allow(adapter).to receive(:detect)

      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.moderation_status).to eq('skipped')
      expect(upload.moderation_skip_reason).to eq('TOO_LARGE')
      expect(adapter).not_to have_received(:detect)
    end
  end

  context 'when moderation is switched off' do
    before do
      allow(adapter).to receive(:detect)
      allow(Settings.participant_uploads.moderation).to receive(:enabled).and_return(false)
    end

    it 'says so instead of leaving the upload pending forever' do
      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.moderation_status).to eq('skipped')
      expect(upload.moderation_skip_reason).to eq('MODERATION_DISABLED')
      expect(adapter).not_to have_received(:detect)
    end
  end

  context 'when the service keeps failing' do
    before { allow(adapter).to receive(:detect).and_raise(Aws::Rekognition::Errors::ThrottlingException.new(nil, 'slow down')) }

    it 'retries first instead of recording a verdict on the first error' do
      expect { described_class.perform_now(upload.id) }.to have_enqueued_job(described_class).with(upload.id)
      expect(upload.reload.moderation_status).to eq('pending')
    end

    it 'ends as failed once the attempts run out, never as checked' do
      perform_enqueued_jobs(only: described_class) { described_class.perform_later(upload.id) }
      upload.reload

      expect(upload.moderation_status).to eq('failed')
      expect(upload.moderation_labels).to eq([])
      expect(Sentry).to have_received(:capture_exception)
    end

    it 'keeps serving the file, because moderation never blocks access' do
      perform_enqueued_jobs(only: described_class) { described_class.perform_later(upload.id) }
      upload.reload

      expect(upload).to be_servable
      expect(upload.file).to be_attached
    end
  end

  describe 'when it runs' do
    it 'is queued the moment the scanner calls the file clean' do
      pending_upload = create(:participant_upload)

      expect { pending_upload.mark_clean! }
        .to have_enqueued_job(described_class).with(pending_upload.id)
    end

    it 'does not run on a file the scanner has not cleared' do
      expect { create(:participant_upload) }.not_to have_enqueued_job(described_class)
    end

    it 'does not run twice on the same upload' do
      allow(adapter).to receive(:detect).and_return(nothing_found)
      described_class.perform_now(upload.id)

      described_class.perform_now(upload.id)

      expect(adapter).to have_received(:detect).once
    end

    it 'does nothing when the upload is gone' do
      expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
    end
  end

  describe 'when the scanner removes the file first' do
    it 'closes the moderation as skipped, with the reason the file is gone' do
      pending_upload = create(:participant_upload)

      perform_enqueued_jobs(only: described_class) { pending_upload.close!(:infected) }
      pending_upload.reload

      expect(pending_upload.moderation_status).to eq('skipped')
      expect(pending_upload.moderation_skip_reason).to eq('FILE_REMOVED_BY_SECURITY_SCAN')
      expect(pending_upload.moderation_labels).to eq([])
      expect(pending_upload.moderated_at).to be_present
    end

    it 'never calls that a failure, which would mean moderation ran and broke' do
      pending_upload = create(:participant_upload)

      pending_upload.close!(:unreadable)

      expect(pending_upload.reload.moderation_status).not_to eq('failed')
    end

    it 'leaves a verdict that already exists alone' do
      moderated = create(:participant_upload, :clean)
      moderated.complete_moderation!([{ 'name' => 'Violence', 'confidence' => 92.4 }], '7.0')

      moderated.close!(:infected)
      moderated.reload

      expect(moderated.moderation_status).to eq('completed')
      expect(moderated.moderation_labels).to eq([{ 'name' => 'Violence', 'confidence' => 92.4 }])
      expect(moderated.moderation_skip_reason).to be_nil
    end

    it 'does not leave the job to run on a file that no longer exists' do
      pending_upload = create(:participant_upload)
      pending_upload.close!(:infected)

      allow(adapter).to receive(:detect)
      described_class.perform_now(pending_upload.id)

      expect(adapter).not_to have_received(:detect)
    end
  end

  describe 'what the record keeps' do
    before { allow(adapter).to receive(:detect).and_return(flagged) }

    it 'keeps the labels out of the audit trail' do
      described_class.perform_now(upload.id)

      expect(upload.reload.audits.last.audited_changes.keys)
        .not_to include('moderation_labels', 'moderation_labels_ciphertext')
    end

    it 'stores the labels encrypted' do
      described_class.perform_now(upload.id)

      ciphertext = ParticipantUpload.connection.select_value(
        ParticipantUpload.sanitize_sql_array(
          ['select moderation_labels_ciphertext from participant_uploads where id = ?', upload.id]
        )
      )

      expect(ciphertext).to be_present
      expect(ciphertext).not_to include('Violence')
    end
  end
end
