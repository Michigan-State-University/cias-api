# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/user_sessions/:user_session_id/previous_question', type: :request do
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user_id: researcher.id, status: 'published') }
  let(:request) { get v1_user_session_previous_question_path(user_session.id), headers: participant.create_new_auth_token, params: params }
  let(:params) { {} }

  context 'UserSession::Classic' do
    let!(:session) { create(:session, intervention_id: intervention.id) }
    let!(:question_group) { create(:question_group, session: session) }
    let!(:question1) { create(:question_single, question_group: question_group) }
    let!(:question2) { create(:question_single, question_group: question_group) }
    let(:user_int) { create(:user_intervention, intervention: intervention, user: participant) }
    let!(:user_session) { create(:user_session, user: participant, session: session, user_intervention: user_int) }

    context 'when the intervention is paused' do
      let(:user) { researcher }

      it_behaves_like 'paused intervention'
    end

    context 'when user session hasn\'t any answers' do
      it 'return empty body' do
        request
        expect(json_response['data']).to be(nil)
        expect(json_response['answer']).to be(nil)
      end
    end

    context 'when user want to see last question -  first undo' do
      let!(:answer) { create(:answer_single, question: question1, user_session: user_session) }

      it 'return correct question id' do
        request
        expect(json_response['data']['id']).to eq(question1.id)
      end

      it 'return answer with question' do
        request
        expect(json_response['answer']['id']).to eq(answer.id)
      end

      it 'return only excpected keys' do
        request
        expect(json_response.keys).to match_array(%w[data answer])
      end

      context 'when user has two answers for the same question' do
        let!(:answer2) { create(:answer_single, question: question1, user_session: user_session, created_at: DateTime.parse('2022-10-02T08:25:47+02:00')) }

        it 'return correct question id' do
          request
          expect(json_response['data']['id']).to eq(question1.id)
        end

        it 'mark both answers as draft' do
          request
          expect(answer.reload.draft).to be true
          expect(answer2.reload.draft).to be true
        end
      end
    end

    context 'when user want to see last question -  second undo' do
      let!(:answer1) { create(:answer_single, question: question1, user_session: user_session) }
      let!(:answer2) { create(:answer_single, question: question2, user_session: user_session) }

      context 'when previous question does not have reflection' do
        let(:params) { { current_question_id: question2.id } }

        it 'return correct question id' do
          request
          expect(json_response['data']['id']).to eq(question1.id)
        end

        it 'return answer with question' do
          request
          expect(json_response['answer']['id']).to eq(answer1.id)
        end

        it 'change answer to draft' do
          request
          expect(answer1.reload.draft).to be(true)
        end
      end

      context 'when previous question has reflection' do
        let!(:question2) { create(:question_single, :narrator_blocks_with_cases, question_group: question_group) }
        let!(:question3) { create(:question_single, question_group: question_group) }
        let!(:answer3) { create(:answer_single, question: question3, user_session: user_session) }
        let(:params) { { current_question_id: question3.id } }

        it 'return narrator block with type Reflection' do
          request
          expect(
            json_response['data']['attributes']['narrator']['blocks'].map do |block|
              block['type']
            end
          ).to include('ReflectionFormula')
        end
      end
    end

    context 'user will see last final answer' do
      let!(:question3) { create(:question_single, question_group: question_group) }
      let!(:question4) { create(:question_single, question_group: question_group) }
      let!(:answer1) { create(:answer_single, question: question1, user_session: user_session, created_at: 6.hours.ago) }
      let!(:answer2) { create(:answer_single, question: question2, user_session: user_session, draft: true, created_at: 4.hours.ago) }
      let!(:answer3) { create(:answer_single, question: question3, user_session: user_session, draft: true, alternative_branch: true, created_at: 2.hours.ago) }
      let!(:answer4) { create(:answer_single, question: question4, user_session: user_session, created_at: 5.hours.ago) }

      it 'return correct question id' do
        request
        expect(json_response['data']['id']).to eq(question4.id)
      end
    end

    context 'when the intervention is draft - researcher wants to back to question without answer' do
      let!(:intervention) { create(:intervention, user_id: researcher.id, status: 'draft') }
      let(:params) { { current_question_id: question2.id } }

      it 'return correct body' do
        request
        expect(json_response['data']['id']).to eq(question1.id)
        expect(json_response['answer']).to be(nil)
      end
    end
  end

  context 'with henry ford integration' do
    let(:participant) { create(:user, :confirmed, :participant, :with_hfhs_patient_detail) }
    let!(:intervention) { create(:intervention, user_id: researcher.id, status: 'published', hfhs_access: true) }
    let!(:session) { create(:session, intervention_id: intervention.id) }
    let!(:question_group) { create(:question_group, session: session) }
    let!(:question1) { create(:question_henry_ford_initial_screen, question_group: question_group) }
    let!(:answer) { create(:answer_henry_ford_initial, question: question1, user_session: user_session) }
    let(:user_int) { create(:user_intervention, intervention: intervention, user: participant) }
    let!(:user_session) { create(:user_session, user: participant, session: session, user_intervention: user_int) }

    it 'contain information about patient details' do
      request
      hfhs_patient_detail = participant.hfhs_patient_detail
      expect(json_response['hfhs_patient_detail']).to include(
        { 'patient_id' => participant.hfhs_patient_detail.patient_id,
          'zip_code' => hfhs_patient_detail.provided_zip,
          'first_name' => hfhs_patient_detail.provided_first_name,
          'last_name' => hfhs_patient_detail.provided_last_name,
          'dob' => hfhs_patient_detail.provided_dob,
          'sex' => hfhs_patient_detail.provided_sex,
          'phone_number' => hfhs_patient_detail.provided_phone_number,
          'phone_type' => hfhs_patient_detail.provided_phone_type }
      )
    end

    it 'have all expected kayes in hfh\'s section' do
      request
      expect(json_response['hfhs_patient_detail'].keys).to match_array(%w[patient_id first_name last_name dob sex zip_code phone_number phone_type])
    end
  end

  context 'UserSession::CatMh' do
    let(:session) { create(:cat_mh_session, :with_test_type_and_variables, :with_cat_mh_info, intervention: intervention) }
    let(:user_int) { create(:user_intervention, intervention: intervention, user: participant) }
    let!(:user_session) { create(:user_session_cat_mh, user: participant, session: session, user_intervention: user_int) }

    it 'returns correct status code (Unprocessable entity)' do
      request
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'sends validation error message' do
      request
      expect(json_response['message']).to eq 'Previous question is unavailable for this type of session'
    end
  end
end
