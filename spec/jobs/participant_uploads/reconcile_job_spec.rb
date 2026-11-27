# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParticipantUploads::ReconcileJob, type: :job do
  include ActiveJob::TestHelper

  let(:upload) { create(:participant_upload) }

  def age!(record, by)
    record.update_columns(created_at: by.ago, updated_at: by.ago)
  end

  context 'when a pending upload still has its bytes' do
    it 'gives it another scan job, because the first one was never enqueued' do
      age!(upload, described_class::STALE_AFTER + 1.minute)

      expect { described_class.perform_now }
        .to have_enqueued_job(ParticipantUploads::ScanJob).with(upload.id)
    end
  end

  context 'when a pending upload already spent every scan attempt' do
    before do
      allow(Sentry).to receive(:capture_message)
      upload.update!(scan_attempts: ParticipantUploads::ScanJob::MAX_PENDING_ATTEMPTS)
      age!(upload, described_class::STALE_AFTER + 1.minute)
    end

    it 'closes it instead of handing it another scan job on every run' do
      expect { described_class.perform_now }.not_to have_enqueued_job(ParticipantUploads::ScanJob)

      expect(upload.reload.scan_status).to eq('deleted')
      expect(upload.deletion_reason).to eq('SCANNER_CANNOT_INSPECT')
    end

    it 'leaves nothing for the next run to pick up' do
      described_class.perform_now

      expect { described_class.perform_now }.not_to have_enqueued_job(ParticipantUploads::ScanJob)
    end
  end

  context 'when a pending upload has no stored file' do
    before { upload.file.blob.service.delete(upload.file.blob.key) }

    it 'closes it fail-closed rather than leaving it pending forever' do
      age!(upload, described_class::STALE_AFTER + 1.minute)

      described_class.perform_now

      expect(upload.reload.scan_status).to eq('deleted')
      expect(upload.deletion_reason).to eq('SCANNER_CANNOT_INSPECT')
    end

    it 'keeps the record so the researcher still sees a note' do
      age!(upload, described_class::STALE_AFTER + 1.minute)

      expect { described_class.perform_now }.not_to change(ParticipantUpload, :count)
    end
  end

  context 'when one object is unreachable' do
    let(:unreachable) { create(:participant_upload) }
    let(:healthy) { create(:participant_upload) }

    before do
      allow(Sentry).to receive(:capture_exception)
      age!(unreachable, described_class::STALE_AFTER + 2.minutes)
      age!(healthy, described_class::STALE_AFTER + 1.minute)
      broken_key = unreachable.file.blob.key
      allow(ActiveStorage::Blob.service).to receive(:exist?).and_wrap_original do |original, key|
        raise Errno::ECONNREFUSED if key == broken_key

        original.call(key)
      end
    end

    it 'does not restart the whole sweep because of one unreachable object' do
      expect { described_class.perform_now }.not_to have_enqueued_job(described_class)
    end

    it 'still reconciles the rest of the sweep' do
      expect { described_class.perform_now }
        .to have_enqueued_job(ParticipantUploads::ScanJob).with(healthy.id)
    end

    it 'leaves the unreachable row pending for the next sweep instead of destroying its file' do
      described_class.perform_now

      expect(unreachable.reload.scan_status).to eq('pending')
      expect(unreachable.file).to be_attached
    end

    it 'reports the unreachable object instead of dropping it silently' do
      described_class.perform_now

      expect(Sentry).to have_received(:capture_exception)
        .with(instance_of(Errno::ECONNREFUSED), extra: { participant_upload_id: unreachable.id })
    end
  end

  it 'leaves a scan chain that is still touching the row alone' do
    upload.update_columns(created_at: (described_class::STALE_AFTER + 1.minute).ago, updated_at: Time.current)

    expect { described_class.perform_now }.not_to have_enqueued_job(ParticipantUploads::ScanJob)
  end

  it 'leaves uploads still inside the scan window alone' do
    upload

    expect { described_class.perform_now }.not_to have_enqueued_job(ParticipantUploads::ScanJob)
  end

  context 'when a closed upload still carries its bytes' do
    before do
      upload.update!(scan_status: 'deleted', deleted_at: Time.current,
                     deletion_reason: ParticipantUpload::MALWARE_DELETION_REASON)
      age!(upload, described_class::IDLE_AFTER + 1.minute)
    end

    it 'purges the file, because close! was interrupted before it got there' do
      expect { described_class.perform_now }
        .to have_enqueued_job(ActiveStorage::PurgeJob)
    end

    it 'detaches the file so the next sweep has nothing left to do' do
      perform_enqueued_jobs { described_class.perform_now }

      expect(upload.reload.file).not_to be_attached
    end
  end

  context 'when a clean upload never reached the moderator' do
    before do
      upload.update!(scan_status: 'clean')
      age!(upload, described_class::IDLE_AFTER + 1.minute)
    end

    it 'hands it another moderation job, because the first enqueue was lost' do
      expect { described_class.perform_now }
        .to have_enqueued_job(ParticipantUploads::ModerationJob).with(upload.id)
    end

    it 'leaves an upload the moderator already answered alone' do
      upload.update!(moderation_status: 'completed')
      age!(upload, described_class::IDLE_AFTER + 1.minute)

      expect { described_class.perform_now }
        .not_to have_enqueued_job(ParticipantUploads::ModerationJob)
    end
  end

  it 'leaves uploads that already have a verdict alone' do
    upload.update!(scan_status: 'clean')
    age!(upload, described_class::STALE_AFTER + 1.minute)

    expect { described_class.perform_now }.not_to have_enqueued_job(ParticipantUploads::ScanJob)
  end
end
