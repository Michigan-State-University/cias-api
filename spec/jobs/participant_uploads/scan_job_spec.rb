# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParticipantUploads::ScanJob, type: :job do
  include ActiveJob::TestHelper

  let(:upload) { create(:participant_upload) }
  let(:adapter) { instance_double(V1::ParticipantUploads::GuardDutyS3Adapter) }

  before { allow(V1::ParticipantUploads::GuardDutyS3Adapter).to receive(:new).and_return(adapter) }

  context 'when the scanner says clean' do
    before { allow(adapter).to receive(:scan).and_return(:clean) }

    it 'marks the upload clean and keeps the file' do
      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.scan_status).to eq('clean')
      expect(upload.file).to be_attached
    end
  end

  context 'when the scanner says infected' do
    before { allow(adapter).to receive(:scan).and_return(:infected) }

    it 'deletes the file and leaves a tombstone' do
      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.scan_status).to eq('deleted')
      expect(upload.deletion_reason).to eq('MALWARE_DETECTED')
      expect(upload.deleted_at).to be_present
    end

    it 'keeps the record so the researcher sees a note, not an empty cell' do
      upload

      expect { described_class.perform_now(upload.id) }.not_to change(ParticipantUpload, :count)
    end

    it 'logs the upload id and the reason, never the participant filename' do
      logged = []
      allow(Rails.logger).to receive(:warn) { |line| logged << line.to_s }

      described_class.perform_now(upload.id)

      expect(logged.join(' ')).to include(upload.id, 'MALWARE_DETECTED')
      expect(logged.join(' ')).not_to include('wyniki badania')
    end
  end

  context 'when the scanner cannot inspect the file' do
    before do
      allow(adapter).to receive(:scan).and_return(:unreadable)
      allow(Sentry).to receive(:capture_message)
    end

    it 'treats it as rejected, never as clean' do
      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.scan_status).to eq('deleted')
      expect(upload.deletion_reason).to eq('SCANNER_CANNOT_INSPECT')
    end

    it 'raises an alarm, because a file destroyed without a verdict needs an operator' do
      described_class.perform_now(upload.id)

      expect(Sentry).to have_received(:capture_message).with(
        'participant upload removed without a scan verdict',
        hash_including(level: :warning, extra: hash_including(deletion_reason: 'SCANNER_CANNOT_INSPECT'))
      )
    end

    it 'logs at warn, because production drops info' do
      allow(Rails.logger).to receive(:warn)

      described_class.perform_now(upload.id)

      expect(Rails.logger).to have_received(:warn).with(/#{upload.id}/)
    end
  end

  context 'when GuardDuty could not read the object' do
    before do
      allow(Sentry).to receive(:capture_message)
      allow(adapter).to receive(:scan).and_return(:scanner_misconfigured)
    end

    it 'ends the upload instead of leaving it pending for a verdict that never comes' do
      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.scan_status).to eq('deleted')
      expect(upload.deleted_at).to be_present
    end

    it 'names our configuration as the reason, not the file' do
      described_class.perform_now(upload.id)

      expect(upload.reload.deletion_reason).to eq(ParticipantUpload::CONFIGURATION_DELETION_REASON)
    end

    it 'does not enqueue another attempt' do
      expect { described_class.perform_now(upload.id) }.not_to have_enqueued_job(described_class)
    end

    it 'reports it to Sentry at error level, because it is ours to fix' do
      described_class.perform_now(upload.id)

      expect(Sentry).to have_received(:capture_message).with(/could not read it/, hash_including(level: :error))
    end
  end

  context 'when the scanner is misconfigured' do
    before { allow(Sentry).to receive(:capture_exception) }

    [V1::ParticipantUploads::GuardDutyS3Adapter::ScanStatusUnavailableError,
     V1::ParticipantUploads::GuardDutyS3Adapter::UnsupportedServiceError,
     V1::ParticipantUploads::Scanner::UnknownScannerError,
     V1::ParticipantUploads::Scanner::InsecureScannerError].each do |error|
      it "keeps the participant file while the budget for #{error} lasts" do
        allow(adapter).to receive(:scan).and_raise(error, 'misconfigured')

        expect { described_class.perform_now(upload.id) }.not_to change { upload.reload.scan_status }
        expect(upload.file).to be_attached
      end

      it "closes the upload once the budget for #{error} is gone, so it stops coming back" do
        allow(adapter).to receive(:scan).and_raise(error, 'misconfigured')
        allow(Sentry).to receive(:capture_message)

        perform_enqueued_jobs(only: described_class) { described_class.perform_later(upload.id) }
        upload.reload

        expect(upload.scan_status).to eq('deleted')
        expect(upload.deletion_reason).to eq(ParticipantUpload::CONFIGURATION_DELETION_REASON)
      end
    end

    it 'reports the fault at error level, so Sentry shows it as ours and not as the file fault' do
      allow(adapter).to receive(:scan).and_raise(V1::ParticipantUploads::GuardDutyS3Adapter::ScanStatusUnavailableError)

      described_class.perform_now(upload.id)

      expect(Sentry).to have_received(:capture_exception)
        .with(instance_of(V1::ParticipantUploads::GuardDutyS3Adapter::ScanStatusUnavailableError), level: :error)
    end
  end

  context 'when writing the attempt counter fails' do
    before do
      allow(Sentry).to receive(:capture_exception)
      allow(upload_record).to receive(:update!).with(hash_including(:scan_attempts)).and_raise(ActiveRecord::StatementInvalid, 'deadlock')
      allow(ParticipantUpload).to receive(:find_by).with(id: upload.id).and_return(upload_record)
    end

    let(:upload_record) { ParticipantUpload.find(upload.id) }

    it 'does not launder a record error into a destroyed file' do
      allow(adapter).to receive(:scan).and_return(:clean)

      expect do
        perform_enqueued_jobs(only: described_class) { described_class.perform_later(upload.id) }
      end.to raise_error(Minitest::UnexpectedError) { |wrapper| expect(wrapper.error).to be_a(ActiveRecord::StatementInvalid) }

      expect(upload.reload.scan_status).to eq('pending')
      expect(upload.file).to be_attached
    end
  end

  context 'when the scan has not finished yet' do
    before { allow(adapter).to receive(:scan).and_return(:pending) }

    it 'leaves the upload pending' do
      described_class.perform_now(upload.id)

      expect(upload.reload.scan_status).to eq('pending')
    end

    it 'comes back in seconds, not in an hour' do
      expect { described_class.perform_now(upload.id) }
        .to have_enqueued_job(described_class).at(a_value_within(5.seconds).of(described_class::PENDING_RETRY_WAIT.from_now))
    end

    it 'gives up fail-closed once the scan deadline passes' do
      upload.update!(scan_attempts: described_class::MAX_PENDING_ATTEMPTS)

      described_class.perform_now(upload.id)
      upload.reload

      expect(upload.scan_status).to eq('deleted')
      expect(upload.deletion_reason).to eq('SCANNER_CANNOT_INSPECT')
    end

    it 'stops rescheduling itself once it gave up' do
      upload.update!(scan_attempts: described_class::MAX_PENDING_ATTEMPTS)

      expect { described_class.perform_now(upload.id) }.not_to have_enqueued_job(described_class)
    end
  end

  context 'when the scanner keeps blowing up' do
    before do
      allow(adapter).to receive(:scan).and_raise(StandardError, 'clamd down')
      allow(Sentry).to receive(:capture_exception)
    end

    it 'retries while attempts are left' do
      expect { described_class.perform_now(upload.id) }.to have_enqueued_job(described_class)
      expect(upload.reload.scan_status).to eq('pending')
    end

    it 'keeps quiet while a retry is still coming, so one outage is one Sentry event' do
      perform_enqueued_jobs(only: described_class) { described_class.perform_later(upload.id) }

      expect(Sentry).to have_received(:capture_exception).once
    end

    it 'comes back in a minute, not after the hour ApplicationJob waits' do
      expect { described_class.perform_now(upload.id) }
        .to have_enqueued_job(described_class).at(a_value_within(20.seconds).of(described_class::ERROR_RETRY_WAIT.from_now))
    end

    it 'survives an outage of minutes and still ends before the scan window' do
      expect(described_class::ERROR_RETRY_WAIT * described_class::MAX_ATTEMPTS).to be > 5.minutes
      expect(described_class::ERROR_RETRY_WAIT * described_class::MAX_ATTEMPTS).to be < ParticipantUpload::SCAN_WINDOW
    end

    it 'spends the whole budget and ends fail-closed, never re-raised' do
      perform_enqueued_jobs(only: described_class) { described_class.perform_later(upload.id) }

      expect(upload.reload.scan_status).to eq('deleted')
      expect(upload.deletion_reason).to eq('SCANNER_CANNOT_INSPECT')
    end

    it 'gives up and rejects once the attempts run out' do
      job = described_class.new(upload.id)
      job.executions = described_class::MAX_ATTEMPTS - 1

      job.perform_now
      upload.reload

      expect(upload.scan_status).to eq('deleted')
      expect(upload.deletion_reason).to eq('SCANNER_CANNOT_INSPECT')
    end

    it 'does not spend the error budget on polling' do
      upload.update!(scan_attempts: described_class::MAX_ATTEMPTS + 5)

      expect { described_class.perform_now(upload.id) }.to have_enqueued_job(described_class)
      expect(upload.reload.scan_status).to eq('pending')
    end
  end

  describe 'the error budget' do
    it 'stays reachable, so a failing scanner ends in a verdict and not in pending' do
      allow(adapter).to receive(:scan).and_raise(StandardError, 'clamd down')
      allow(Sentry).to receive(:capture_exception)
      job = described_class.new(upload.id)
      job.executions = described_class::MAX_ATTEMPTS

      job.perform_now

      expect(upload.reload.scan_status).to eq('deleted')
    end
  end

  describe 'enqueueing' do
    it 'waits for the transaction to commit' do
      expect(described_class.enqueue_after_transaction_commit).to be(true)
    end

    it 'is not enqueued when the surrounding transaction rolls back' do
      expect do
        ActiveRecord::Base.transaction do
          described_class.perform_later(upload.id)
          raise ActiveRecord::Rollback
        end
      end.not_to have_enqueued_job(described_class)
    end
  end

  context 'when the upload was already scanned' do
    let(:upload) { create(:participant_upload, :clean) }

    it 'does nothing' do
      allow(adapter).to receive(:scan)

      described_class.perform_now(upload.id)

      expect(adapter).not_to have_received(:scan)
    end
  end

  context 'when the upload is gone' do
    it 'does nothing' do
      expect { described_class.perform_now(SecureRandom.uuid) }.not_to raise_error
    end
  end
end
