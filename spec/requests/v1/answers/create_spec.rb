# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/questions/:question_id/answers', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:guest) { create(:user, :guest) }
  let(:question) { create(:question_text_box) }

  let(:params_without_user) do
    {
      answer: {
        type: 'Answer::TextBox',
        body: {
          data: [
            {
              payload: '1',
              variable: '1'
            }
          ]
        }
      }
    }
  end

  let(:params_with_user) do
    {
      answer: {
        type: 'Answer::TextBox',
        user_id: user.id,
        body: {
          data: [
            {
              payload: '1',
              variable: '1'
            }
          ]
        }
      }
    }
  end

  before { post v1_answers_path(question.id), params: params, headers: user.create_new_auth_token }

  context 'current_user is admin' do
    let(:user) { admin }

    context 'when params' do
      context 'are VALID' do
        context 'is without user' do
          let(:params) { params_without_user }

          it { expect(response).to have_http_status(:created) }

          it 'returns proper attributes' do
            expect(json_response['data']['attributes']).to include(
              'type' => 'Answer::TextBox',
              'question' => include(
                'id' => question.id
              ),
              'user' => nil,
              'body' => {
                'data' => [
                  {
                    'payload' => '1',
                    'variable' => '1'
                  }
                ]
              }
            )
          end
        end

        context 'is with user' do
          let(:params) { params_with_user }

          it { expect(response).to have_http_status(:created) }

          it 'returns proper attributes' do
            expect(json_response['data']['attributes']).to include(
              'type' => 'Answer::TextBox',
              'question' => include(
                'id' => question.id
              ),
              'user' => include(
                'id' => user.id
              ),
              'body' => {
                'data' => [
                  {
                    'payload' => '1',
                    'variable' => '1'
                  }
                ]
              }
            )
          end
        end
      end
    end
  end

  context 'current_user is researcher' do
    let(:user) { researcher }

    context 'intervention belongs to researcher' do
      let!(:intervention) { create(:intervention, user: researcher) }
      let!(:question) { create(:question_text_box, intervention: intervention) }

      context 'when params' do
        context 'are VALID' do
          context 'is without user' do
            let(:params) { params_without_user }

            it { expect(response).to have_http_status(:created) }

            it 'returns proper attributes' do
              expect(json_response['data']['attributes']).to include(
                'type' => 'Answer::TextBox',
                'question' => include(
                  'id' => question.id
                ),
                'user' => nil,
                'body' => {
                  'data' => [
                    {
                      'payload' => '1',
                      'variable' => '1'
                    }
                  ]
                }
              )
            end
          end

          context 'is with user' do
            let(:params) { params_with_user }

            it { expect(response).to have_http_status(:created) }

            it 'returns proper attributes' do
              expect(json_response['data']['attributes']).to include(
                'type' => 'Answer::TextBox',
                'question' => include(
                  'id' => question.id
                ),
                'user' => include(
                  'id' => user.id
                ),
                'body' => {
                  'data' => [
                    {
                      'payload' => '1',
                      'variable' => '1'
                    }
                  ]
                }
              )
            end
          end
        end
      end
    end

    context 'intervention does not belong to researcher' do
      let(:user) { participant }
      let(:params) { params_without_user }

      it { expect(response).to have_http_status(:forbidden) }

      it 'response contains proper error message' do
        expect(json_response['message']).to eq 'You are not authorized to access this page.'
      end
    end
  end

  context 'current_user is participant' do
    let(:user) { participant }
    let(:params) { params_without_user }

    it { expect(response).to have_http_status(:forbidden) }

    it 'response contains proper error message' do
      expect(json_response['message']).to eq 'You are not authorized to access this page.'
    end
  end

  context 'current_user is guest' do
    let(:user) { guest }

    context 'when params' do
      context 'are VALID' do
        context 'is without user' do
          let(:params) { params_without_user }

          it { expect(response).to have_http_status(:created) }

          it 'returns proper attributes' do
            expect(json_response['data']['attributes']).to include(
              'type' => 'Answer::TextBox',
              'question' => include(
                'id' => question.id
              ),
              'user' => nil,
              'body' => {
                'data' => [
                  {
                    'payload' => '1',
                    'variable' => '1'
                  }
                ]
              }
            )
          end
        end
      end

      context 'is with user' do
        let(:params) { params_with_user }

        it { expect(response).to have_http_status(:created) }

        it 'returns proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'type' => 'Answer::TextBox',
            'question' => include(
              'id' => question.id
            ),
            'user' => include(
              'id' => user.id
            ),
            'body' => {
              'data' => [
                {
                  'payload' => '1',
                  'variable' => '1'
                }
              ]
            }
          )
        end
      end
    end
  end
end
