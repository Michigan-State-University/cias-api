# frozen_string_literal: true

require 'rails_helper'

describe 'PATCH /v1/users/:id', type: :request do
  let(:admin) { create(:user, :admin, first_name: 'Smith', last_name: 'Wazowski') }
  let(:user_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:researcher) { create(:user, :confirmed, :researcher, first_name: 'Smith', last_name: 'Wazowski') }
  let(:researcher_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant researcher guest]) }
  let(:e_intervention_admin) { create(:user, :confirmed, :e_intervention_admin) }
  let(:other_user) { create(:user, :confirmed) }
  let(:users) do
    {
      'admin' => admin,
      'user_with_multiple_roles' => user_with_multiple_roles,
      'other_user' => other_user,
      'researcher' => researcher,
      'researcher_with_multiple_roles' => researcher_with_multiple_roles,
      'e_intervention_admin' => e_intervention_admin
    }
  end
  let(:current_user) { admin }
  let(:params) do
    {
      user: {
        first_name: 'John',
        last_name: 'Kowalski',
        sms_notification: false,
        description: 'Some details about user'
      }
    }
  end
  let(:user_id) { current_user.id }
  let(:session) { nil }
  let(:question_group) { nil }
  let(:question) { nil }
  let(:answer) { nil }

  before { patch v1_user_path(user_id), headers: current_user.create_new_auth_token, params: params }

  context 'when current_user is admin' do
    shared_examples 'admin' do
      context 'when current_user updates itself' do
        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'first_name' => 'John',
            'last_name' => 'Kowalski',
            'email' => current_user.email,
            'avatar_url' => nil,
            'description' => 'Some details about user'
          )
        end

        it 'updates user attributes' do
          expect(current_user.reload.attributes).to include(
            'first_name' => 'John',
            'last_name' => 'Kowalski',
            'sms_notification' => false,
            'description' => 'Some details about user'
          )
        end

        context 'when current_user tries to update deactivated and roles attributes' do
          let(:params) do
            {
              user: {
                roles: %w[admin guest],
                active: false
              }
            }
          end

          it { expect(response).to have_http_status(:ok) }

          it 'JSON response contains proper attributes' do
            expect(json_response['data']['attributes']).to include(
              'roles' => %w[admin guest],
              'active' => false
            )
          end

          it 'updates user attributes' do
            expect(current_user.reload.attributes).to include(
              'roles' => %w[admin guest],
              'active' => false
            )
          end
        end

        context 'with invalid first_name and last_name params' do
          let(:params) do
            {
              user: {
                first_name: '',
                last_name: ''
              }
            }
          end

          it { expect(response).to have_http_status(:unprocessable_entity) }

          it 'contains correct error message' do
            expect(json_response['message']).to include 'First name and last name cannot be blank'
          end
        end
      end

      context 'when current_user updates other user' do
        let(:user_id) { other_user.id }

        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'first_name' => 'John',
            'last_name' => 'Kowalski',
            'email' => other_user.email,
            'avatar_url' => nil
          )
        end

        it 'updates user attributes' do
          expect(other_user.reload.attributes).to include(
            'first_name' => 'John',
            'last_name' => 'Kowalski'
          )
        end

        context 'when current_user tries to update deactivated and roles attributes' do
          let(:params) do
            {
              user: {
                roles: %w[admin guest],
                active: false
              }
            }
          end

          it { expect(response).to have_http_status(:ok) }

          it 'JSON response contains proper attributes' do
            expect(json_response['data']['attributes']).to include(
              'roles' => %w[admin guest],
              'active' => false
            )
          end

          it 'updates user attributes' do
            expect(other_user.reload.attributes).to include(
              'roles' => %w[admin guest],
              'active' => false
            )
          end
        end
      end
    end

    %w[admin user_with_multiple_roles].each do |role|
      context "when current user is #{role}" do
        let(:current_user) { users[role] }

        it_behaves_like 'admin'
      end
    end
  end

  context 'when current_user is researcher' do
    shared_examples 'researcher' do
      context 'when current_user updates itself' do
        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'first_name' => 'John',
            'last_name' => 'Kowalski',
            'email' => current_user.email,
            'avatar_url' => nil
          )
        end

        it 'updates user attributes' do
          expect(current_user.reload.attributes).to include(
            'first_name' => 'John',
            'last_name' => 'Kowalski'
          )
        end

        context 'with feedback_completed params' do
          let(:params) do
            {
              user: {
                feedback_completed: true
              }
            }
          end

          it 'updates feedback_completed to true' do
            expect(current_user.reload.feedback_completed).to eq(true)
          end
        end

        context 'when current_user tries to update deactivated and roles attributes' do
          context 'when deactivated user is admin or guest' do
            let(:user_id) { other_user.id }
            let(:params) do
              {
                user: {
                  roles: %w[admin guest],
                  active: true
                }
              }
            end

            it { expect(response).to have_http_status(:not_found) }

            it 'response contains proper error message' do
              expect(json_response['message']).to include "Couldn't find User with"
            end
          end

          context 'when deactivated user is participant' do
            context 'with answer' do
              let!(:other_user) { create(:user, :participant, :confirmed, active: false) }
              let!(:user_id) { other_user.id }
              let(:intervention) { create(:intervention, user: current_user) }
              let!(:session) { create(:session, intervention: intervention) }
              let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
              let!(:question) { create(:question_slider, question_group: question_group) }
              let(:user_intervention) { create(:user_intervention, intervention: intervention, user: other_user) }
              let!(:answer) do
                create(:answer_slider, question: question,
                                       user_session: create(:user_session, user: other_user, session: session, user_intervention: user_intervention))
              end
              let!(:params) do
                {
                  user: {
                    roles: %w[participant],
                    active: true
                  }
                }
              end

              before { patch v1_user_path(user_id), headers: current_user.create_new_auth_token, params: params }

              it { expect(response).to have_http_status(:ok) }

              it 'JSON response contains proper attributes' do
                expect(json_response['data']['attributes']).to include(
                  'roles' => %w[participant],
                  'active' => true
                )
              end

              it 'updates user attributes' do
                expect(other_user.reload.attributes).to include(
                  'active' => true
                )
              end
            end

            context 'without answer' do
              let(:other_user) { create(:user, :participant, :confirmed) }
              let(:user_id) { other_user.id }
              let(:params) do
                {
                  user: {
                    roles: %w[participant],
                    active: false
                  }
                }
              end

              it { expect(response).to have_http_status(:not_found) }
            end
          end
        end
      end

      context 'when current_user updates participant' do
        let!(:other_user) { create(:user, :participant, :confirmed) }
        let!(:user_id) { other_user.id }
        let(:intervention) { create(:intervention, user: current_user) }
        let!(:session) { create(:session, intervention: intervention) }
        let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
        let!(:question) { create(:question_slider, question_group: question_group) }
        let(:user_intervention) { create(:user_intervention, user: other_user, intervention: intervention) }
        let!(:answer) do
          create(:answer_slider, question: question,
                                 user_session: create(:user_session, user: other_user, session: session, user_intervention: user_intervention))
        end

        before { patch v1_user_path(user_id), headers: current_user.create_new_auth_token, params: params }

        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'first_name' => other_user.first_name,
            'last_name' => other_user.last_name,
            'email' => other_user.email,
            'avatar_url' => nil
          )
        end
      end

      context 'when current_user updates other user' do
        let(:user_id) { other_user.id }

        it { expect(response).to have_http_status(:not_found) }

        it 'response contains proper error message' do
          expect(json_response['message']).to include "Couldn't find User with"
        end
      end
    end

    %w[researcher researcher_with_multiple_roles].each do |role|
      context "when user is #{role}" do
        let!(:current_user) { users[role] }

        it_behaves_like 'researcher'
      end
    end
  end

  context 'when current_user is team admin' do
    let!(:team1) { create(:team) }
    let!(:current_user) { team1.team_admin }
    let(:team_participant) { create(:user, :participant, team_id: team1.id) }
    let(:other_team_participant) { create(:user, :participant, team_id: team1.id) }
    let(:researcher) { create(:user, :researcher, team_id: team1.id) }
    let!(:session) { create(:session, intervention: create(:intervention, user: researcher)) }
    let!(:question_group) { create(:question_group, title: 'Test Question Group', session: session, position: 1) }
    let!(:question) { create(:question_slider, question_group: question_group) }
    let!(:answer) { create(:answer_slider, question: question, user_session: create(:user_session, user: team_participant, session: session)) }
    let(:request) { get v1_users_path, params: params, headers: current_user.create_new_auth_token }

    context 'when current_user updates itself' do
      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski',
          'email' => current_user.email,
          'avatar_url' => nil
        )
      end

      it 'updates user attributes' do
        expect(current_user.reload.attributes).to include(
          'first_name' => 'John',
          'last_name' => 'Kowalski'
        )
      end

      context 'when current_user tries to update deactivated and roles attributes' do
        context 'when deactivated user is admin or guest' do
          let(:user_id) { other_user.id }
          let(:params) do
            {
              user: {
                roles: %w[admin guest],
                active: true
              }
            }
          end

          it { expect(response).to have_http_status(:not_found) }

          it 'response contains proper error message' do
            expect(json_response['message']).to include "Couldn't find User with"
          end
        end

        context 'when deactivated user is participant' do
          context 'with answer' do
            let(:other_user) { team_participant }
            let!(:user_id) { team_participant.id }
            let!(:params) do
              {
                user: {
                  roles: %w[participant],
                  active: false
                }
              }
            end

            before { patch v1_user_path(user_id), headers: current_user.create_new_auth_token, params: params }

            it { expect(response).to have_http_status(:ok) }

            it 'JSON response contains proper attributes' do
              expect(json_response['data']['attributes']).to include(
                'roles' => %w[participant],
                'active' => false
              )
            end

            it 'updates user attributes' do
              expect(team_participant.reload.attributes).to include(
                'active' => false
              )
            end
          end

          context 'without answer' do
            let(:other_user) { other_team_participant }
            let(:user_id) { other_user.id }
            let(:params) do
              {
                user: {
                  roles: %w[participant],
                  active: false
                }
              }
            end

            it { expect(response).to have_http_status(:ok) }
          end
        end
      end
    end

    context 'when user wants to update researcher belongs to him team' do
      let!(:user_id) { team_participant.id }

      it { expect(response).to have_http_status(:ok) }

      it 'JSON response contains proper attributes' do
        expect(json_response['data']['attributes']).to include(
          'first_name' => team_participant.first_name,
          'last_name' => team_participant.last_name,
          'email' => team_participant.email,
          'avatar_url' => nil
        )
      end
    end
  end

  %w[guest participant organization_admin health_system_admin health_clinic_admin third_party].each do |role|
    context "when current_user is #{role}" do
      let(:current_user) { create(:user, :confirmed, role, first_name: 'Smith', last_name: 'Wazowski') }

      context 'when current_user updates itself' do
        it { expect(response).to have_http_status(:ok) }

        it 'JSON response contains proper attributes' do
          expect(json_response['data']['attributes']).to include(
            'first_name' => 'John',
            'last_name' => 'Kowalski',
            'email' => current_user.email,
            'avatar_url' => nil
          )
        end

        it 'updates user attributes' do
          expect(current_user.reload.attributes).to include(
            'first_name' => 'John',
            'last_name' => 'Kowalski'
          )
        end

        context 'when current_user tries to update deactivated and roles attributes' do
          let(:params) do
            {
              user: {
                roles: %w[admin guest],
                deactivated: true
              }
            }
          end

          it { expect(response).to have_http_status(:forbidden) }

          it 'response contains proper error message' do
            expect(json_response['message']).to eq 'You are not authorized to access this page.'
          end
        end
      end

      context 'when current_user updates other user' do
        let(:user_id) { other_user.id }

        it { expect(response).to have_http_status(:not_found) }
      end
    end
  end
end
