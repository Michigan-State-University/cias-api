# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/question_groups/:question_group_id/questions/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:session) { create(:session) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_slider, question_group: question_group) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      question: {
        type: question.type,
        position: 999,
        title: 'Question Test 1',
        subtitle: 'test 1',
        body: {
          data: [
            {
              payload: {
                range_start: 0,
                range_end: 10,
                start_value: 'test 1',
                end_value: 'test 1'
              }
            }
          ],
          variable: {
            name: 'var_test_1'
          }
        }
      }
    }
  end
  let(:request) do
    patch v1_question_group_question_path(question_group_id: question_group.id, id: question.id), params: params,
                                                                                                  headers: headers, as: :json
  end

  context 'when auth' do
    context 'is invalid' do
      let(:request) { patch v1_question_group_question_path(question_group_id: question_group.id, id: question.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when response' do
        context 'is JSON' do
          before do
            patch v1_question_group_question_path(question_group_id: question_group.id, id: question.id),
                  headers: headers
          end

          it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
        end

        context 'contains' do
          before { request }

          it 'to hash success' do
            expect(json_response.class).to be(Hash)
          end

          it 'key question' do
            expect(json_response['data']['type']).to eq('question')
          end
        end
      end

      context 'when intervention is published' do
        let(:session) { create(:session, intervention: create(:intervention, :published)) }

        it 'return correct status' do
          request
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end

  context 'empty formulas' do
    let(:params) do
      {
        question: {
          type: question.type,
          position: 999,
          title: 'Question Test 1',
          subtitle: 'test 1',
          body: {
            data: [
              {
                payload: {
                  range_start: 0,
                  range_end: 10,
                  start_value: 'test 1',
                  end_value: 'test 1'
                }
              }
            ],
            variable: {
              name: 'var_test_1'
            }
          },
          formulas: []
        }
      }
    end

    it 'lets users assign empty array of formulas' do
      request
      expect(json_response['data']['attributes']['formulas']).to eq []
    end
  end

  context 'invalid body data' do
    let(:params) do
      {
        question: {
          type: question.type,
          position: 999,
          title: 'Question Test 1',
          subtitle: 'test 1',
          body: {
            data: [
              {
                payload: {
                  range_start: 0,
                  range_end: 10,
                  start_value: 'test 1',
                  end_value: 'test 1'
                }
              }
            ],
            variable: {
              name: '1_INVALID_VAR***'
            }
          }
        }
      }
    end

    before do
      request
    end

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it 'respond with correct error message' do
      expect(json_response['message']).to eq 'Validation failed: Variable name is in invalid format'
    end
  end

  context 'add params require to allow to reflection from other sessions' do
    let(:params) do
      {
        question: {
          narrator: {
            blocks: [
              {
                text: [
                  'Enter main text/question for screen here'
                ],
                type: 'ReadQuestion',
                action: 'NO_ACTION',
                sha256: [
                  '20165f236db0d64f2e00a4300b56734a6216f03b12e0b44b90f9b7a38bf7c1af'
                ],
                animation: 'rest',
                audio_urls: [],
                endPosition: {
                  x: 600,
                  y: 550
                }
              },
              {
                action: 'NO_ACTION',
                question_id: '536dfa63-68d6-440c-a96e-96b123f5a96f',
                reflections: [
                  {
                    variable: 'v1',
                    value: '1',
                    payload: '',
                    text: [],
                    sha256: [],
                    audio_urls: []
                  }
                ],
                animation: 'rest',
                type: 'Reflection',
                endPosition: {
                  x: 600,
                  y: 550
                }
              }
            ],
            settings: {
              voice: true,
              animation: true,
              character: 'peedy'
            }
          }
        }
      }
    end

    before do
      request
    end

    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end
  end
end
