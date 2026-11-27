# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::UserSessions::ParticipantUploads', type: :request do
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:intervention) { create(:intervention, :published) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_file_upload, question_group: question_group) }
  let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
  let(:user_session) do
    create(:user_session, user: participant, session: session, user_intervention: user_intervention)
  end
  let(:headers) { participant.create_new_auth_token }
  let(:png_bytes) { "\x89PNG\r\n\x1a\n".b + ("\x00" * 64) }

  def post_presign(bytes: png_bytes, filename: 'scan.png', byte_size: nil, checksum: nil, as: headers)
    post presign_v1_user_session_participant_uploads_path(user_session.id),
         params: { question_id: question.id,
                   blob: { filename: filename,
                           byte_size: byte_size || bytes.bytesize,
                           checksum: checksum || Digest::MD5.base64digest(bytes),
                           content_type: 'application/octet-stream' } },
         headers: as
  end

  def participant_upload_blobs
    ActiveStorage::Blob.where('key LIKE ?', "#{V1::ParticipantUploads::Presign::KEY_PREFIX}/%").count
  end

  def put_bytes(url, bytes)
    put URI.parse(url).request_uri, params: bytes, headers: { 'CONTENT_TYPE' => 'application/octet-stream' }
  end

  def post_upload(bytes: png_bytes, filename: 'scan.png', description: nil, as: headers, skip_bytes: false)
    post_presign(bytes: bytes, filename: filename, as: as)
    return unless response.successful?

    signed_id = json_response['signed_id']
    put_bytes(json_response['direct_upload']['url'], bytes) unless skip_bytes

    post v1_user_session_participant_uploads_path(user_session.id),
         params: { question_id: question.id,
                   participant_upload: { signed_id: signed_id, original_filename: filename,
                                         description: description }.compact },
         headers: as
  end

  describe 'POST create' do
    context 'without authentication' do
      let(:headers) { {} }

      it 'refuses the upload' do
        post_upload(bytes: png_bytes, filename: 'scan.png')

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with an allowed file' do
      it 'creates a pending upload' do
        expect { post_upload(bytes: png_bytes, filename: 'scan.png') }
          .to change(ParticipantUpload, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(ParticipantUpload.last.scan_status).to eq('pending')
      end

      it 'never parses the bytes before the scanner has ruled on them' do
        user_session && question && headers

        expect { post_upload(bytes: png_bytes, filename: 'scan.png') }
          .not_to have_enqueued_job(ActiveStorage::AnalyzeJob)

        expect(response).to have_http_status(:created)
        expect(ParticipantUpload.last.file.blob).to be_analyzed
      end

      it 'stores the original filename encrypted and attaches the blob under a neutral name' do
        post_upload(bytes: png_bytes, filename: 'wyniki badania.png')
        upload = ParticipantUpload.last

        expect(upload.original_filename).to eq('wyniki badania.png')
        expect(upload.file.blob.filename.to_s).not_to include('wyniki')
      end

      it 'enqueues the scan job' do
        expect { post_upload(bytes: png_bytes, filename: 'scan.png') }
          .to have_enqueued_job(ParticipantUploads::ScanJob)
      end
    end

    context 'with an audio or video file' do
      let(:mp4_bytes) { "\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2avc1mp41".b + ("\x00" * 64) }
      let(:mp3_bytes) { "ID3\x04\x00\x00\x00\x00\x00\x00".b + ("\x00" * 64) }

      it 'accepts a video' do
        post_upload(bytes: mp4_bytes, filename: 'nagranie.mp4')

        expect(response).to have_http_status(:created)
        expect(ParticipantUpload.last.content_type_detected).to eq('video/mp4')
      end

      it 'accepts an audio recording' do
        post_upload(bytes: mp3_bytes, filename: 'nagranie.mp3')

        expect(response).to have_http_status(:created)
        expect(ParticipantUpload.last.content_type_detected).to eq('audio/mpeg')
      end
    end

    context 'request logging' do
      it 'never hands the uploaded file to the request log job' do
        allow(LogJobs::UserRequest).to receive(:perform_later).and_call_original

        post_upload(bytes: png_bytes, filename: 'wyniki badania.png', description: 'moje wyniki')

        expect(response).to have_http_status(:created)
        expect(LogJobs::UserRequest).to have_received(:perform_later).twice do |scope|
          expect(scope.to_s).not_to include('wyniki badania')
          expect(scope.to_s).not_to include('moje wyniki')
        end
      end

      it 'filters the participant description out of Rails logs and Sentry' do
        filtered = ActiveSupport::ParameterFilter
                   .new(Rails.application.config.filter_parameters)
                   .filter('participant_upload' => { 'description' => 'moje wyniki',
                                                     'original_filename' => 'wyniki badania.png' },
                           'blob' => { 'filename' => 'wyniki badania.png' })

        expect(filtered['participant_upload']['description']).to eq('[FILTERED]')
        expect(filtered['participant_upload']['original_filename']).to eq('[FILTERED]')
        expect(filtered['blob']['filename']).to eq('[FILTERED]')
      end
    end

    context 'when the question belongs to another session' do
      let(:foreign_question) do
        create(:question_file_upload, question_group: create(:question_group, session: create(:session)))
      end

      it 'refuses to park a file under it' do
        post presign_v1_user_session_participant_uploads_path(user_session.id),
             params: { question_id: foreign_question.id,
                       blob: { filename: 'scan.png', byte_size: png_bytes.bytesize,
                               checksum: Digest::MD5.base64digest(png_bytes) } },
             headers: headers

        expect(response).to have_http_status(:not_found)
        expect(participant_upload_blobs).to eq(0)
      end
    end

    context 'when the client lies about the content type' do
      it 'stores the detected type on the blob, not the declared one' do
        post_upload(bytes: png_bytes, filename: 'scan.png')

        expect(response).to have_http_status(:created)
        expect(ParticipantUpload.last.file.blob.content_type).to eq('image/png')
      end

      it 'refuses an extension outside the allowlist before a single byte is stored' do
        post_upload(bytes: "notatki z badania\n".b, filename: 'payload.ps1')

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_TYPE_NOT_ALLOWED')
        expect(participant_upload_blobs).to eq(0)
      end

      it 'never lets the participant name reach the blob' do
        post_upload(bytes: png_bytes, filename: 'wyniki badania.png')

        expect(response).to have_http_status(:created)
        expect(ParticipantUpload.last.file.blob.filename.to_s).to start_with('upload_')
      end
    end

    context 'with a disallowed file' do
      it 'returns a reason code, not a ready-made message' do
        post_upload(bytes: "MZ\x90\x00".b + ("\x00" * 64), filename: 'resume.txt')

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_TYPE_NOT_ALLOWED')
      end

      it 'does not leak the filename in the response' do
        post_upload(bytes: "MZ\x90\x00".b + ("\x00" * 64), filename: 'tajne wyniki.txt')

        expect(response.body).not_to include('tajne wyniki')
      end
    end

    context 'when the per-question limit is reached' do
      before do
        Settings.participant_uploads.max_files_per_question.times do
          create(:participant_upload, user_session: user_session, question: question)
        end
      end

      it 'allows one file per question, not more' do
        expect(Settings.participant_uploads.max_files_per_question).to eq(1)
      end

      it 'refuses another file' do
        post_upload(bytes: png_bytes, filename: 'scan.png')

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('TOO_MANY_FILES')
      end
    end

    context 'when the file description field is hidden' do
      it 'drops the description' do
        post_upload(bytes: png_bytes, filename: 'scan.png', description: 'moje wyniki')

        expect(ParticipantUpload.last.description).to be_nil
      end
    end

    context 'when the file description field is shown' do
      before { question.update!(settings: question.settings.merge('show_file_description' => true)) }

      it 'keeps the description' do
        post_upload(bytes: png_bytes, filename: 'scan.png', description: 'moje wyniki')

        expect(ParticipantUpload.last.description).to eq('moje wyniki')
      end
    end

    context 'when the user_session belongs to somebody else' do
      let(:headers) { create(:user, :confirmed, :participant).create_new_auth_token }

      it 'refuses the upload' do
        post_upload(bytes: png_bytes, filename: 'scan.png')

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the upload never reached the storage' do
      it 'refuses a signed id nobody signed' do
        post v1_user_session_participant_uploads_path(user_session.id),
             params: { question_id: question.id,
                       participant_upload: { signed_id: 'not-a-signed-id', original_filename: 'scan.png' } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_MISSING')
      end

      it 'refuses a blob signed for another participant session' do
        other_session = create(:user_session, user: participant, session: create(:session, intervention: intervention),
                                              user_intervention: user_intervention)
        blob = ActiveStorage::Blob.create_before_direct_upload!(
          filename: 'upload_x.png', byte_size: png_bytes.bytesize,
          checksum: Digest::MD5.base64digest(png_bytes), content_type: 'application/octet-stream'
        )

        post v1_user_session_participant_uploads_path(user_session.id),
             params: { question_id: question.id,
                       participant_upload: {
                         signed_id: blob.signed_id(purpose: V1::ParticipantUploads::Presign.purpose(other_session, question)),
                         original_filename: 'scan.png'
                       } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_MISSING')
      end

      it 'refuses a blob signed for another question of the same session' do
        other_question = create(:question_file_upload, question_group: question_group)
        blob = ActiveStorage::Blob.create_before_direct_upload!(
          filename: 'upload_x.png', byte_size: png_bytes.bytesize,
          checksum: Digest::MD5.base64digest(png_bytes), content_type: 'application/octet-stream'
        )

        post v1_user_session_participant_uploads_path(user_session.id),
             params: { question_id: question.id,
                       participant_upload: {
                         signed_id: blob.signed_id(purpose: V1::ParticipantUploads::Presign.purpose(user_session, other_question)),
                         original_filename: 'scan.png'
                       } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_MISSING')
      end

      it 'refuses a request that names no file' do
        post_presign

        post v1_user_session_participant_uploads_path(user_session.id),
             params: { question_id: question.id,
                       participant_upload: { signed_id: json_response['signed_id'] } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_MISSING')
      end

      it 'refuses a blob the participant asked for but never filled' do
        post_upload(skip_bytes: true)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_MISSING')
        expect(ParticipantUpload.count).to eq(0)
      end

      it 'takes the session row lock, so two parallel uploads cannot race past the limit' do
        expect_any_instance_of(UserSession).to receive(:lock!).and_call_original

        post_upload(bytes: png_bytes, filename: 'scan.png')

        expect(response).to have_http_status(:created)
      end

      it 'refuses a blob that is already attached somewhere' do
        post_presign
        signed_id = json_response['signed_id']
        put_bytes(json_response['direct_upload']['url'], png_bytes)
        attached = create(:participant_upload, user_session: user_session, question: question)
        attached.file.attach(ActiveStorage::Blob.find_signed!(
                               signed_id, purpose: V1::ParticipantUploads::Presign.purpose(user_session, question)
                             ))

        post v1_user_session_participant_uploads_path(user_session.id),
             params: { question_id: question.id,
                       participant_upload: { signed_id: signed_id, original_filename: 'scan.png' } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_MISSING')
      end
    end

    context 'when the scanner already removed a file for this question' do
      before { create(:participant_upload, :deleted, user_session: user_session, question: question) }

      it 'lets the participant upload a replacement without deleting the note' do
        expect { post_upload(bytes: png_bytes, filename: 'scan.png') }
          .to change(ParticipantUpload, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(ParticipantUpload.where(scan_status: 'deleted').count).to eq(1)
      end
    end

    context 'when a pending upload is stuck past the scan window' do
      before do
        stuck = create(:participant_upload, user_session: user_session, question: question)
        stuck.update_column(:created_at, (ParticipantUpload::SCAN_WINDOW + 1.minute).ago)
      end

      it 'does not let a lost scan job hold the only slot' do
        post_upload(bytes: png_bytes, filename: 'scan.png')

        expect(response).to have_http_status(:created)
      end
    end

    context 'when a pending upload is still inside the scan window' do
      before { create(:participant_upload, user_session: user_session, question: question) }

      it 'still counts it, so the participant cannot queue a second file' do
        post_upload(bytes: png_bytes, filename: 'scan.png')

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('TOO_MANY_FILES')
      end
    end

    context 'with a large text file' do
      it 'reads it once, not once per validation round' do
        allow(V1::ParticipantUploads::ContentTypeDetector).to receive(:call).and_call_original

        post_upload(bytes: 'a' * 2.megabytes, filename: 'wyniki.csv')

        expect(response).to have_http_status(:created)
        expect(V1::ParticipantUploads::ContentTypeDetector).to have_received(:call).once
        expect(ParticipantUpload.last.byte_size).to eq(2.megabytes)
      end
    end

    context 'when the file is over the size cap' do
      it 'refuses it on the declared size, before any byte is stored' do
        allow(V1::ParticipantUploads::ContentTypeDetector).to receive(:call).and_call_original
        oversize = Settings.participant_uploads.max_size_mb.megabytes + 1.kilobyte

        post_presign(filename: 'big.mp4', byte_size: oversize)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('FILE_TOO_LARGE')
        expect(participant_upload_blobs).to eq(0)
        expect(V1::ParticipantUploads::ContentTypeDetector).not_to have_received(:call)
      end
    end

    context 'when the intervention is paused' do
      before { intervention.update!(status: :paused) }

      it 'refuses the upload like the answers endpoint does' do
        post_upload(bytes: png_bytes, filename: 'scan.png')

        expect(response).to have_http_status(:bad_request)
        expect(json_response['details']['reason']).to eq('INTERVENTION_PAUSED')
      end
    end

    context 'when the session is already finished' do
      before { user_session.update!(finished_at: Time.current) }

      it 'refuses the upload so no file is orphaned outside any answer' do
        expect { post_upload(bytes: png_bytes, filename: 'scan.png') }
          .not_to change(ParticipantUpload, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['details']['reason']).to eq('SESSION_FINISHED')
      end

      it 'refuses deleting a file of a finished session' do
        upload = create(:participant_upload, user_session: user_session, question: question)

        delete v1_user_session_participant_upload_path(user_session.id, upload.id), headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(upload.reload).to be_present
      end
    end
  end

  describe 'throttling' do
    include_context 'with real rack attack store'

    let(:limit) { Settings.participant_uploads.throttle_per_minute }

    it 'counts the participant, not the address they share with the clinic' do
      throttle = Rack::Attack.throttles.fetch('participant_uploads/user')
      env = Rack::MockRequest.env_for(v1_user_session_participant_uploads_path(user_session.id),
                                      method: :post, 'REMOTE_ADDR' => '1.2.3.4', 'HTTP_UID' => 'one@example.com')

      expect(throttle.block.call(Rack::Attack::Request.new(env))).to eq('one@example.com')
    end

    it 'leaves other endpoints alone' do
      throttle = Rack::Attack.throttles.fetch('participant_uploads/user')
      env = Rack::MockRequest.env_for('/v1/user_sessions', method: :post, 'HTTP_UID' => 'one@example.com')

      expect(throttle.block.call(Rack::Attack::Request.new(env))).to be_nil
    end

    it 'answers 429 once the minute budget is spent' do
      limit.times { post_presign }
      expect(response).not_to have_http_status(:too_many_requests)

      post_presign

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe 'GET index and show — the participant follows the scan' do
    let!(:pending_upload) { create(:participant_upload, user_session: user_session, question: question) }

    it 'lists the own uploads with their scan status' do
      get v1_user_session_participant_uploads_path(user_session.id), headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first['attributes']['scan_status']).to eq('pending')
    end

    it 'tells the participant which file was rejected and why' do
      removed = create(:participant_upload, :deleted, user_session: user_session, question: question)

      get v1_user_session_participant_upload_path(user_session.id, removed.id), headers: headers

      expect(response).to have_http_status(:ok)
      attributes = json_response['data']['attributes']
      expect(attributes['scan_status']).to eq('deleted')
      expect(attributes['deletion_reason']).to eq('MALWARE_DETECTED')
      expect(attributes['original_filename']).to eq('wyniki badania.png')
      expect(attributes).not_to have_key('url')
    end

    it 'refuses to show somebody else upload' do
      other_headers = create(:user, :confirmed, :participant).create_new_auth_token

      get v1_user_session_participant_upload_path(user_session.id, pending_upload.id), headers: other_headers

      expect(response).to have_http_status(:not_found)
    end

    it 'refuses an unauthenticated request' do
      get v1_user_session_participant_uploads_path(user_session.id)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'moderation never reaches the participant' do
    let!(:moderated) do
      create(:participant_upload, :clean, user_session: user_session, question: question).tap do |upload|
        upload.complete_moderation!([{ 'name' => 'Violence', 'confidence' => 92.4 }], '7.0')
      end
    end

    it 'keeps the verdict out of the list the participant polls' do
      get v1_user_session_participant_uploads_path(user_session.id), headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Violence')
      expect(json_response['data'].first['attributes'].keys).not_to include(
        'moderation_status', 'moderation_labels', 'moderation_skip_reason', 'moderation_model_version'
      )
    end

    it 'keeps the verdict out of a single upload the participant asks for' do
      get v1_user_session_participant_upload_path(user_session.id, moderated.id), headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Violence')
      expect(json_response['data']['attributes']).not_to have_key('moderation_status')
    end
  end

  describe 'an admin from outside the intervention' do
    let(:admin_headers) { create(:user, :confirmed, :admin).create_new_auth_token }
    let!(:upload) { create(:participant_upload, user_session: user_session, question: question) }

    it 'is handed no participant metadata through index' do
      get v1_user_session_participant_uploads_path(user_session.id), headers: admin_headers

      expect(json_response['data']).to be_empty
    end

    it 'is refused the single upload' do
      get v1_user_session_participant_upload_path(user_session.id, upload.id), headers: admin_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'cannot park a file in the participant session' do
      expect do
        post_presign(as: admin_headers)
      end.not_to change(ParticipantUpload, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'DELETE destroy' do
    let!(:upload) { create(:participant_upload, user_session: user_session, question: question) }

    it 'removes the participant own upload' do
      expect do
        delete v1_user_session_participant_upload_path(user_session.id, upload.id), headers: headers
      end.to change(ParticipantUpload, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'refuses to remove somebody else upload' do
      other_headers = create(:user, :confirmed, :participant).create_new_auth_token

      expect do
        delete v1_user_session_participant_upload_path(user_session.id, upload.id), headers: other_headers
      end.not_to change(ParticipantUpload, :count)
    end

    it 'refuses to delete a tombstone the scanner left behind' do
      tombstone = create(:participant_upload, :deleted, user_session: user_session, question: question)

      delete v1_user_session_participant_upload_path(user_session.id, tombstone.id), headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['details']['reason']).to eq('FILE_REMOVED_BY_SECURITY_SCAN')
      expect(ParticipantUpload.exists?(tombstone.id)).to be(true)
    end
  end
end
