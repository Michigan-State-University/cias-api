# frozen_string_literal: true

RSpec.describe ParticipantUpload, type: :model do
  subject(:participant_upload) { build(:participant_upload) }

  describe 'associations' do
    it { should belong_to(:user_session) }
    it { should belong_to(:question) }
    it { should be_valid }
  end

  describe 'scan_status' do
    it 'starts as pending' do
      expect(described_class.new.scan_status).to eq('pending')
    end

    it 'rejects an unknown status' do
      participant_upload.scan_status = 'whatever'
      expect(participant_upload).not_to be_valid
    end
  end

  describe '#close!' do
    subject(:participant_upload) { create(:participant_upload) }

    it 'writes the malware reason for an infected verdict' do
      participant_upload.close!(:infected)

      expect(participant_upload.deletion_reason).to eq(described_class::MALWARE_DELETION_REASON)
    end

    it 'writes the configuration reason when the scanner could not read the file' do
      participant_upload.close!(:scanner_misconfigured)

      expect(participant_upload.deletion_reason).to eq(described_class::CONFIGURATION_DELETION_REASON)
    end

    it 'falls back to the unreadable reason for any other verdict' do
      participant_upload.close!(:unreadable)

      expect(participant_upload.deletion_reason).to eq(described_class::UNREADABLE_DELETION_REASON)
    end

    it 'marks the record deleted whatever the reason' do
      participant_upload.close!(:scanner_misconfigured)

      expect(participant_upload.scan_status).to eq('deleted')
      expect(participant_upload.deleted_at).to be_present
    end
  end

  describe 'content type validation' do
    it 'accepts a type from the allowlist' do
      expect(participant_upload).to be_valid
    end

    it 'rejects a type outside the allowlist' do
      participant_upload.content_type_detected = 'application/x-msdownload'

      expect(participant_upload).not_to be_valid
      expect(participant_upload.errors[:content_type_detected]).to be_present
    end

    it 'keeps a tombstone valid without a type, because the scanner purged the file' do
      upload = build(:participant_upload, :deleted, content_type_detected: nil)

      expect(upload).to be_valid
    end
  end

  describe 'size validation' do
    it 'rejects a file over the configured limit' do
      oversized = "\x89PNG\r\n\x1a\n".b + ("\x00" * (Settings.participant_uploads.max_size_mb.megabytes + 1))
      upload = build(:participant_upload, bytes: oversized)

      expect(upload).not_to be_valid
      expect(upload.errors[:file].join).to include('size')
    end

    it 'accepts a file of exactly the size the API advertises' do
      upload = build(:participant_upload)
      upload.file.blob.byte_size = Settings.participant_uploads.max_size_mb.megabytes

      expect(upload).to be_valid
    end
  end

  describe 'PHI' do
    it 'stores the original filename encrypted' do
      upload = create(:participant_upload, original_filename: 'wyniki badania.png')
      ciphertext = described_class.connection.select_value(
        described_class.sanitize_sql_array(
          ['select original_filename_ciphertext from participant_uploads where id = ?', upload.id]
        )
      )

      expect(upload.reload.original_filename).to eq('wyniki badania.png')
      expect(ciphertext).to be_present
      expect(ciphertext).not_to include('wyniki')
    end

    it 'keeps the original filename out of the audit trail' do
      upload = create(:participant_upload)
      expect(upload.audits.last.audited_changes.keys).not_to include('original_filename', 'original_filename_ciphertext')
    end
  end

  describe 'lifecycle' do
    it 'is destroyed together with its user_session' do
      upload = create(:participant_upload)

      expect { upload.user_session.destroy }.to change(described_class, :count).by(-1)
    end

    it 'schedules the blob for purge when the record is destroyed' do
      upload = create(:participant_upload)
      attachment = upload.file.attachment

      expect { upload.destroy }.to have_enqueued_job(ActiveStorage::PurgeJob).with(attachment.blob)
    end

    it 'schedules the blob for purge when the user_session is destroyed' do
      upload = create(:participant_upload)
      blob = upload.file.blob

      expect { upload.user_session.destroy }.to have_enqueued_job(ActiveStorage::PurgeJob).with(blob)
    end
  end
end
