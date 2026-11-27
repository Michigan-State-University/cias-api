# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::ParticipantUploads', type: :request do
  let(:owner) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: owner) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_file_upload, question_group: question_group) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
  let(:user_session) do
    create(:user_session, user: participant, session: session, user_intervention: user_intervention)
  end
  let(:upload) do
    create(:participant_upload, :clean, user_session: user_session, question: question)
  end

  def get_file(as:)
    get v1_participant_upload_file_path(upload.id), headers: as.create_new_auth_token
  end

  describe 'GET file — access' do
    it 'serves the file to the intervention owner' do
      get_file(as: owner)

      expect(response).to have_http_status(:ok)
    end

    it 'refuses another researcher' do
      get_file(as: create(:user, :confirmed, :researcher))

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses an admin who does not own the intervention' do
      get_file(as: create(:user, :confirmed, :admin))

      expect(response).to have_http_status(:forbidden)
    end

    it 'serves the file to a collaborator with data access' do
      collaborator = create(:user, :confirmed, :researcher)
      create(:collaborator, user: collaborator, intervention: intervention, data_access: true)

      get_file(as: collaborator)

      expect(response).to have_http_status(:ok)
    end

    it 'refuses a collaborator without data access' do
      collaborator = create(:user, :confirmed, :researcher)
      create(:collaborator, user: collaborator, intervention: intervention, data_access: false, view: true)

      get_file(as: collaborator)

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses the participant who uploaded it' do
      get_file(as: participant)

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses an unauthenticated request' do
      get v1_participant_upload_file_path(upload.id)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET file — fail closed' do
    context 'when the scan has not finished' do
      let(:upload) { create(:participant_upload, user_session: user_session, question: question) }

      it 'does not serve the file' do
        get_file(as: owner)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_PENDING_SCAN')
      end
    end

    context 'when the scanner removed the file' do
      let(:upload) { create(:participant_upload, :deleted, user_session: user_session, question: question) }

      it 'answers 410 with the reason' do
        get_file(as: owner)

        expect(response).to have_http_status(:gone)
        expect(json_response['details']['reason']).to eq('FILE_REMOVED_BY_SECURITY_SCAN')
        expect(json_response['details']['deletion_reason']).to eq('MALWARE_DETECTED')
        expect(Time.zone.parse(json_response['details']['deleted_at'])).to be_within(1.minute).of(upload.deleted_at)
      end
    end
  end

  describe 'GET file — disposition' do
    it 'shows an image inline' do
      get_file(as: owner)

      expect(response.headers['Content-Disposition']).to start_with('inline')
      expect(response.headers['Content-Type']).to eq('image/png')
    end

    it 'forces a download for a file outside the preview allowlist' do
      upload = create(:participant_upload, :clean, user_session: user_session, question: question,
                                                   bytes: "kolumna,wartosc\n1,2\n".b,
                                                   upload_filename: 'wyniki.csv',
                                                   declared_content_type: 'text/csv',
                                                   content_type_detected: 'text/plain')

      get v1_participant_upload_file_path(upload.id), headers: owner.create_new_auth_token

      expect(response.headers['Content-Disposition']).to start_with('attachment')
    end

    it 'forces a download for heic' do
      upload = create(:participant_upload, :clean, user_session: user_session, question: question,
                                                   bytes: "\x00\x00\x00\x18ftypheic".b + ("\x00" * 64),
                                                   upload_filename: 'zdjecie.heic',
                                                   declared_content_type: 'image/heic',
                                                   content_type_detected: 'image/heic')

      get v1_participant_upload_file_path(upload.id), headers: owner.create_new_auth_token

      expect(response.headers['Content-Disposition']).to start_with('attachment')
    end

    it 'follows the application allowlist, not only what ActiveStorage would allow inline' do
      allow(Settings.participant_uploads).to receive(:inline_preview_content_types).and_return(['application/pdf'])

      get_file(as: owner)

      expect(upload.content_type_detected).to eq('image/png')
      expect(response.headers['Content-Disposition']).to start_with('attachment')
    end
  end

  describe 'GET show — metadata without the user session id' do
    def get_metadata(as:)
      get v1_participant_upload_path(upload.id), headers: as.create_new_auth_token
    end

    it 'answers with the attributes the researcher page needs' do
      get_metadata(as: owner)

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']).to include(
        'original_filename' => upload.original_filename,
        'content_type_detected' => 'image/png',
        'byte_size' => upload.byte_size,
        'scan_status' => 'clean',
        'inline_preview' => true
      )
    end

    context 'when the scan has not finished' do
      let(:upload) { create(:participant_upload, user_session: user_session, question: question) }

      it 'answers with the pending status instead of refusing' do
        get_metadata(as: owner)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['scan_status']).to eq('pending')
        expect(json_response['data']['attributes']).not_to have_key('url')
      end
    end

    context 'when the scanner removed the file' do
      let(:upload) { create(:participant_upload, :deleted, user_session: user_session, question: question) }

      it 'answers with the deletion reason instead of refusing' do
        get_metadata(as: owner)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['scan_status']).to eq('deleted')
        expect(json_response['data']['attributes']['deletion_reason']).to eq('MALWARE_DETECTED')
      end
    end

    it 'serves a collaborator with data access' do
      collaborator = create(:user, :confirmed, :researcher)
      create(:collaborator, user: collaborator, intervention: intervention, data_access: true)

      get_metadata(as: collaborator)

      expect(response).to have_http_status(:ok)
    end

    it 'refuses a collaborator without data access' do
      collaborator = create(:user, :confirmed, :researcher)
      create(:collaborator, user: collaborator, intervention: intervention, data_access: false, view: true)

      get_metadata(as: collaborator)

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses another researcher' do
      get_metadata(as: create(:user, :confirmed, :researcher))

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses the participant who uploaded it' do
      get_metadata(as: participant)

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses an unauthenticated request' do
      get v1_participant_upload_path(upload.id)

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not download the file to answer' do
      expect_any_instance_of(ActiveStorage::Blob).not_to receive(:download)

      get_metadata(as: owner)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET show — what the researcher learns about moderation' do
    def get_metadata(as:)
      get v1_participant_upload_path(upload.id), headers: as.create_new_auth_token
    end

    it 'tells the researcher the moderation has not finished yet' do
      get_metadata(as: owner)

      attributes = json_response['data']['attributes']
      expect(attributes['moderation_status']).to eq('pending')
      expect(attributes['moderation_labels']).to eq([])
    end

    it 'hands over the categories once they are known' do
      upload.complete_moderation!([{ 'name' => 'Violence', 'confidence' => 92.4 }], '7.0')

      get_metadata(as: owner)

      attributes = json_response['data']['attributes']
      expect(attributes['moderation_status']).to eq('completed')
      expect(attributes['moderation_labels']).to eq([{ 'name' => 'Violence', 'confidence' => 92.4 }])
      expect(attributes['moderation_model_version']).to eq('7.0')
    end

    it 'separates checked and found nothing from never checked' do
      upload.skip_moderation!(ParticipantUpload::UNSUPPORTED_FORMAT_SKIP_REASON)

      get_metadata(as: owner)

      attributes = json_response['data']['attributes']
      expect(attributes['moderation_status']).to eq('skipped')
      expect(attributes['moderation_skip_reason']).to eq('UNSUPPORTED_FORMAT')
    end

    it 'keeps the moderation out of reach of a researcher who may not see the file' do
      upload.complete_moderation!([{ 'name' => 'Violence', 'confidence' => 92.4 }], '7.0')

      get_metadata(as: create(:user, :confirmed, :researcher))

      expect(response).to have_http_status(:forbidden)
      expect(response.body).not_to include('Violence')
    end
  end

  describe 'the ActiveStorage blob route' do
    it 'never serves a participant file, even to the intervention owner' do
      get rails_blob_path(upload.file, only_path: true), headers: owner.create_new_auth_token

      expect(response).to have_http_status(:not_found)
    end

    it 'never builds a variant of a participant file before refusing it' do
      variant_path = rails_representation_path(upload.file.variant(resize_to_limit: [10, 10]), only_path: true)
      built = false
      allow_any_instance_of(ActiveStorage::Blob).to receive(:representation) { built = true }

      get variant_path

      expect(response).to have_http_status(:not_found)
      expect(built).to be(false)
    end

    %w[on off].each do |forgery_protection|
      it "refuses the stock direct upload endpoint with forgery protection #{forgery_protection}" do
        allow(ActionController::Base).to receive(:allow_forgery_protection).and_return(forgery_protection == 'on')

        post rails_direct_uploads_path,
             params: { blob: { filename: 'x.txt', byte_size: 3, checksum: Digest::MD5.base64digest('abc'),
                               content_type: 'text/plain' } }

        expect(response).to have_http_status(:not_found)
        expect(ActiveStorage::Blob.where(filename: 'x.txt')).to be_empty
      end
    end
  end

  describe 'GET file — throttling' do
    around do |example|
      store = Rack::Attack.cache.store
      enabled = Rack::Attack.enabled
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
      Rack::Attack.enabled = true
      Rack::Attack.reset!
      example.run
    ensure
      Rack::Attack.enabled = enabled
      Rack::Attack.cache.store = store
    end

    before { allow(Settings.participant_uploads).to receive(:download_throttle_per_minute).and_return(2) }

    it 'stops a caller that keeps pulling the file' do
      2.times do
        get_file(as: owner)
        expect(response).to have_http_status(:ok)
      end

      get_file(as: owner)

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers['Retry-After'].to_i).to be_positive
    end

    it 'does not count the metadata endpoint against the download budget' do
      5.times { get v1_participant_upload_path(upload.id), headers: owner.create_new_auth_token }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET config' do
    it 'exposes the allowlist and the limits' do
      get v1_participant_uploads_config_path, headers: participant.create_new_auth_token

      expect(response).to have_http_status(:ok)
      expect(json_response['allowed_content_types']).to eq(Settings.participant_uploads.allowed_content_types)
      expect(json_response['max_size_bytes']).to eq(Settings.participant_uploads.max_size_mb.megabytes)
      expect(json_response['max_files_per_question']).to eq(Settings.participant_uploads.max_files_per_question)
      expect(json_response['inline_preview_content_types']).not_to include('image/heic')
    end

    it 'refuses a role that has no business with the upload feature' do
      get v1_participant_uploads_config_path, headers: create(:user, :confirmed, :navigator).create_new_auth_token

      expect(response).to have_http_status(:forbidden)
    end

    it 'serves the researcher who edits the question' do
      get v1_participant_uploads_config_path, headers: owner.create_new_auth_token

      expect(response).to have_http_status(:ok)
    end

    it 'refuses an anonymous caller' do
      get v1_participant_uploads_config_path

      expect(response).to have_http_status(:unauthorized)
    end

    it 'exposes the extensions the file picker should offer' do
      get v1_participant_uploads_config_path, headers: participant.create_new_auth_token

      expect(json_response['accepted_extensions']).to eq(Settings.participant_uploads.accepted_extensions)
      expect(json_response['accepted_extensions']).to include('csv', 'heic', 'docx', 'xls')
      expect(json_response['accepted_extensions']).to include('mp3', 'wav', 'mp4', 'mov')
      expect(json_response['accepted_extensions']).not_to include('exe', 'ps1')
    end
  end
end
