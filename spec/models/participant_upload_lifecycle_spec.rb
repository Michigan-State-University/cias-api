# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ParticipantUpload lifecycle', type: :model do
  include ActiveJob::TestHelper

  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: researcher) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_file_upload, question_group: question_group) }

  describe 'cloning a question' do
    it 'copies the configuration and no participant file' do
      user_session = create(:user_session, session: session)
      create(:participant_upload, question: question, user_session: user_session)

      clone = nil
      expect { clone = question.clone }
        .not_to change(ParticipantUpload, :count)

      expect(clone.settings['show_file_description']).to eq(question.settings['show_file_description'])
      expect(clone.participant_uploads).to be_empty
    end
  end

  describe 'publishing the intervention' do
    it 'removes preview uploads together with the preview users' do
      preview_user = create(:user, :confirmed, :preview_session, preview_session_id: session.id)
      user_intervention = create(:user_intervention, user: preview_user, intervention: intervention)
      preview_session = create(:user_session, user: preview_user, session: session, user_intervention: user_intervention)
      create(:participant_upload, question: question, user_session: preview_session)

      expect { V1::Intervention::Publish.new(intervention).execute }
        .to change(ParticipantUpload, :count).by(-1)
    end
  end

  describe 'destroying a user_session' do
    it 'takes its uploads with it' do
      user_session = create(:user_session, session: session)
      create(:participant_upload, question: question, user_session: user_session)

      expect { user_session.destroy }.to change(ParticipantUpload, :count).by(-1)
    end

    it 'purges the stored bytes, not only the records' do
      user_session = create(:user_session, session: session)
      create(:participant_upload, question: question, user_session: user_session)

      expect do
        perform_enqueued_jobs { user_session.destroy }
      end.to change(ActiveStorage::Blob, :count).by(-1)
        .and change(ActiveStorage::Attachment, :count).by(-1)
    end
  end

  describe 'a tombstone the scanner left behind' do
    it 'keeps the size the purged blob can no longer tell' do
      user_session = create(:user_session, session: session)
      upload = create(:participant_upload, question: question, user_session: user_session)
      size = upload.byte_size

      perform_enqueued_jobs { upload.close!(:infected) }

      expect(upload.reload.file).not_to be_attached
      expect(upload.byte_size).to eq(size)
    end
  end

  describe 'destroying a question' do
    it 'takes its uploads with it' do
      user_session = create(:user_session, session: session)
      create(:participant_upload, question: question, user_session: user_session)

      expect { question.destroy }.to change(ParticipantUpload, :count).by(-1)
    end
  end
end
