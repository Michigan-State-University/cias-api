# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::AnswerSerializer do
  let(:question) { create(:question_file_upload) }
  let(:user_session) { create(:user_session) }
  let(:clean_upload) { create(:participant_upload, :clean, question: question, user_session: user_session) }
  let(:deleted_upload) { create(:participant_upload, :deleted, question: question, user_session: user_session) }

  def serialize(answer)
    described_class.new(answer).serializable_hash[:data][:attributes]
  end

  context 'for a file upload answer' do
    let(:answer) do
      Answer::FileUpload.create!(
        question: question, user_session: user_session,
        body: { 'data' => [{ 'var' => 'file_upload_var', 'value' => [clean_upload.id, deleted_upload.id] }] }
      )
    end

    it 'exposes every referenced upload' do
      expect(serialize(answer)[:participant_uploads].pluck(:id))
        .to contain_exactly(clean_upload.id, deleted_upload.id)
    end

    it 'exposes the scan status of each upload' do
      statuses = serialize(answer)[:participant_uploads].to_h { |u| [u[:id], u[:scan_status]] }

      expect(statuses[clean_upload.id]).to eq('clean')
      expect(statuses[deleted_upload.id]).to eq('deleted')
    end

    it 'hands out no file url, because the download endpoint refuses the participant' do
      keys = serialize(answer)[:participant_uploads].flat_map(&:keys).uniq

      expect(keys).not_to include(:url)
    end

    it 'explains why a removed upload has no url' do
      removed = serialize(answer)[:participant_uploads].find { |u| u[:id] == deleted_upload.id }

      expect(removed[:deletion_reason]).to eq('MALWARE_DETECTED')
    end
  end

  context 'for any other answer type' do
    let(:answer) { create(:answer_free_response) }

    it 'adds nothing' do
      expect(serialize(answer)).not_to have_key(:participant_uploads)
    end
  end
end
