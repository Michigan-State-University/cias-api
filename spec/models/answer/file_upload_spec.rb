# frozen_string_literal: true

RSpec.describe Answer::FileUpload, type: :model do
  let(:question) { create(:question_file_upload) }
  let(:user_session) { create(:user_session) }
  let(:clean_upload) { create(:participant_upload, :clean, question: question, user_session: user_session) }
  let(:pending_upload) { create(:participant_upload, question: question, user_session: user_session) }
  let(:deleted_upload) { create(:participant_upload, :deleted, question: question, user_session: user_session) }
  let(:host) { ENV.fetch('WEB_URL', nil) }

  def answer_for(*upload_ids)
    described_class.create!(
      question: question,
      user_session: user_session,
      body: { 'data' => [{ 'var' => 'file_upload_var', 'value' => upload_ids }] }
    )
  end

  describe 'type integrity' do
    it 'is accepted for a Question::FileUpload' do
      expect(answer_for(clean_upload.id)).to be_persisted
    end
  end

  describe 'ownership of the referenced uploads' do
    it 'accepts uploads from its own user_session and question' do
      expect(answer_for(clean_upload.id)).to be_persisted
    end

    it 'refuses an upload belonging to another user_session' do
      foreign = create(:participant_upload, :clean, question: question, user_session: create(:user_session))

      expect { answer_for(foreign.id) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'refuses an upload belonging to another question' do
      other_question = create(:question_file_upload, question_group: question.question_group)
      foreign = create(:participant_upload, :clean, question: other_question, user_session: user_session)

      expect { answer_for(foreign.id) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'refuses an upload that does not exist' do
      expect { answer_for(SecureRandom.uuid) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'refuses the same upload twice, because one file must not count as two' do
      expect { answer_for(clean_upload.id, clean_upload.id) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'names the duplicate as the reason' do
      answer = described_class.new(
        question: question,
        user_session: user_session,
        body: { 'data' => [{ 'var' => 'file_upload_var', 'value' => [clean_upload.id, clean_upload.id] }] }
      )

      answer.valid?

      expect(answer.errors[:body]).to include('references the same file more than once')
    end
  end

  describe 'the value the intervention logic sees' do
    def variable_value
      user_session.reload.all_var_values(include_session_var: false)['file_upload_var']
    end

    it 'counts the files instead of handing a formula a list of ids' do
      answer_for(clean_upload.id)

      expect(variable_value).to eq(1)
    end

    it 'counts a file still being scanned, because branching happens before the verdict' do
      answer_for(pending_upload.id)

      expect(variable_value).to eq(1)
    end

    it 'stays what it was when the scanner removes the file afterwards' do
      answer_for(clean_upload.id)
      clean_upload.close!(:infected)

      expect(variable_value).to eq(1)
    end

    it 'is zero when the participant answered without a file' do
      answer_for

      expect(variable_value).to eq(0)
    end

    it 'ignores a blank entry rather than counting it' do
      described_class.create!(
        question: question,
        user_session: user_session,
        body: { 'data' => [{ 'var' => 'file_upload_var', 'value' => ['', nil] }] }
      )

      expect(variable_value).to eq(0)
    end
  end

  describe '#csv_header_name' do
    it 'returns the question variable regardless of the data entry' do
      answer = answer_for(clean_upload.id)

      expect(answer.csv_header_name({})).to eq('file_upload_var')
    end
  end

  describe '#csv_row_value' do
    it 'joins protected links for many clean uploads' do
      second = create(:participant_upload, :clean, question: question, user_session: user_session)
      answer = answer_for(clean_upload.id, second.id)

      expect(answer.csv_row_value(answer.decrypted_body['data'].first)).to eq(
        "#{host}/participant-uploads/#{clean_upload.id}\n#{host}/participant-uploads/#{second.id}"
      )
    end

    it 'marks an upload still waiting for the scanner' do
      answer = answer_for(pending_upload.id)

      expect(answer.csv_row_value(answer.decrypted_body['data'].first)).to eq('FILE PENDING SCAN')
    end

    it 'marks an upload removed by the scanner' do
      answer = answer_for(deleted_upload.id)

      expect(answer.csv_row_value(answer.decrypted_body['data'].first)).to eq('FILE REMOVED BY SECURITY SCAN')
    end

    it 'does not blame the scanner for an upload the participant deleted themselves' do
      answer = answer_for(clean_upload.id)
      clean_upload.destroy!

      expect(answer.csv_row_value(answer.decrypted_body['data'].first)).to eq('FILE NO LONGER AVAILABLE')
    end

    it 'never produces an empty cell' do
      answer = answer_for(clean_upload.id, pending_upload.id, deleted_upload.id)

      expect(answer.csv_row_value(answer.decrypted_body['data'].first).split("\n")).to all(be_present)
    end

    it 'does not leak the protected link for a pending upload' do
      answer = answer_for(pending_upload.id)

      expect(answer.csv_row_value(answer.decrypted_body['data'].first)).not_to include(pending_upload.id)
    end
  end
end
