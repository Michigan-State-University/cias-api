# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/question_groups/:question_group_id/questions', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:question_group) { create(:question_group) }
  let(:headers) { user.create_new_auth_token }
  let(:blocks) { [] }
  let(:params) do
    {
      question: {
        type: 'Question::Multiple',
        position: 99,
        title: 'Question Test 1',
        subtitle: 'test 1',
        formulas: [{
          payload: 'test',
          patterns: [
            {
              match: '= 5',
              target: [{
                type: 'Session',
                probability: '100',
                id: ''
              }]
            },
            {
              match: '> 5',
              target: [{
                type: 'Question',
                probability: '100',
                id: ''
              }]
            }
          ]
        }],
        body: {
          data: [
            {
              payload: 'create1',
              variable: {
                name: 'test1',
                value: '1'
              }
            },
            {
              payload: 'create2',
              variable: {
                name: 'test2',
                value: '2'
              }
            }
          ]
        },
        narrator: {
          blocks: blocks,
          settings: {
            voice: true,
            animation: true
          }
        }
      }
    }
  end
  let(:request) { post v1_question_group_questions_path(question_group.id), params: params, headers: headers, as: :json }

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when auth' do
        context 'is invalid' do
          let(:request) { post v1_question_group_questions_path(question_group.id) }

          it_behaves_like 'unauthorized user'
        end

        context 'is valid' do
          it_behaves_like 'authorized user'
        end
      end

      context 'when response' do
        context 'is JSON' do
          before { request }

          it {
            expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
          }
        end

        context 'is JSON and parse' do
          before { request }

          it 'success to Hash' do
            expect(json_response.class).to be(Hash)
          end
        end
      end

      context 'created' do
        before { request }

        it 'has correct formula size' do
          expect(json_response['data']['attributes']['formulas'][0]['patterns'].size).to eq(2)
        end

        it 'has correct patterns data' do
          expect(json_response['data']['attributes']['formulas'][0]['patterns'][1]).to include('match' => '> 5', 'target' => [{ 'id' => '', 'type' => 'Question', 'probability' => '100' }])
        end

        it 'has correct body data size' do
          expect(json_response['data']['attributes']['body']['data'].size).to eq(2)
        end

        it 'has correct body data attributes' do
          expect(json_response['data']['attributes']['body']['data'][0]).to include('payload' => 'create1', 'variable' => { 'value' => '1', 'name' => 'test1' })
        end
      end

      context 'when blocks' do
        context 'has not been passed' do
          before { request }

          it 'do not create narrator blocks' do
            expect(json_response['data']['attributes']['narrator']['blocks'].size).to be(0)
          end
        end

        context 'has been passed' do
          let(:blocks) do
            [
              {
                action: 'NO_ACTION',
                animation: 'rest',
                audio_urls: [],
                end_position: {
                  x: 600,
                  y: 600
                },
                sha256: [],
                text: ['Enter main text/question for screen here'],
                type: 'ReadQuestion'
              }
            ]
          end

          before { request }

          it('has correct blocks size') do
            expect(json_response['data']['attributes']['narrator']['blocks'].size).to be(1)
          end

          it('creates audio url correctly') do
            expect(json_response['data']['attributes']['narrator']['blocks'][0]['audio_urls'].size).to be(1)
          end
        end
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when user has multiple roles' do
      let(:user) { admin_with_multiple_roles }

      it_behaves_like 'permitted user'
    end
  end
end
