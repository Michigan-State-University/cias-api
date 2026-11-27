# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::UserSessions::Answers for Answer::FileUpload', type: :request do
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:intervention) { create(:intervention, :published, user: researcher) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_file_upload, question_group: question_group) }
  let(:user_intervention) { create(:user_intervention, user: participant, intervention: intervention) }
  let(:user_session) do
    create(:user_session, user: participant, session: session, user_intervention: user_intervention)
  end
  let(:upload) { create(:participant_upload, :clean, user_session: user_session, question: question) }

  def post_answer(value, question_id: question.id)
    post v1_user_session_answers_path(user_session.id),
         params: {
           answer: { type: 'Answer::FileUpload', body: { data: [{ var: 'file_upload_var', value: value }] } },
           question_id: question_id
         },
         headers: participant.create_new_auth_token
  end

  describe 'POST create' do
    it 'accepts an array of upload ids and answers with the serialized uploads' do
      post_answer([upload.id])

      expect(response).to have_http_status(:created)
      expect(json_response['data']['attributes']['participant_uploads'].pluck('id')).to eq([upload.id])
    end

    it 'keeps the upload ids in the stored body' do
      post_answer([upload.id])

      expect(Answer::FileUpload.last.body_data.first['value']).to eq([upload.id])
    end

    it 'refuses an upload that belongs to another participant session' do
      other_session = create(:user_session, session: session)
      foreign = create(:participant_upload, :clean, user_session: other_session, question: question)

      post_answer([foreign.id])

      expect(response).not_to have_http_status(:created)
      expect(Answer::FileUpload.count).to eq(0)
    end

    it 'accepts an empty answer when the participant attached nothing' do
      post_answer([])

      expect(response).to have_http_status(:created)
      expect(json_response['data']['attributes']['participant_uploads']).to eq([])
    end
  end

  describe 'GET index' do
    let(:second_question) { create(:question_file_upload, question_group: question_group) }
    let(:second_upload) { create(:participant_upload, :clean, user_session: user_session, question: second_question) }

    def answer_for(answered_question, answered_upload)
      Answer::FileUpload.create!(
        question: answered_question,
        user_session: user_session,
        body: { 'data' => [{ 'var' => 'file_upload_var', 'value' => [answered_upload.id] }] }
      )
    end

    before do
      answer_for(question, upload)
      answer_for(second_question, second_upload)
    end

    it 'loads the uploads of every answer in one query, not one query per answer' do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] if payload[:sql].include?('participant_uploads') && payload[:name] != 'SCHEMA'
      end

      get v1_user_session_answers_path(user_session.id), headers: researcher.create_new_auth_token

      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(response).to have_http_status(:ok)
      expect(queries.size).to eq(1)
    end

    it 'never carries the moderation verdict through the answer payload' do
      upload.complete_moderation!([{ 'name' => 'Violence', 'confidence' => 92.4 }], '7.0')

      get v1_user_session_answers_path(user_session.id), headers: researcher.create_new_auth_token

      expect(response.body).not_to include('Violence')
      expect(json_response['data'].flat_map { |answer| answer['attributes']['participant_uploads'] }.compact)
        .to all(satisfy { |upload| !upload.key?('moderation_status') })
    end

    it 'hands the researcher the uploads of each answer' do
      get v1_user_session_answers_path(user_session.id), headers: researcher.create_new_auth_token

      serialized = json_response['data'].to_h { |answer| [answer['id'], answer['attributes']['participant_uploads'].pluck('id')] }

      expect(serialized.values).to contain_exactly([upload.id], [second_upload.id])
    end
  end
end
