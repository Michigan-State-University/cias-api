# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/invitations', type: :request do
  let!(:user) { create(:user, :confirmed, :researcher, created_at: 1.day.ago) }
  let!(:participant) { create(:user, :confirmed, :participant) }
  let!(:intervention) { create(:flexible_order_intervention, status: intervention_status, user_id: user.id, shared_to: 'registered') }
  let!(:intervention_status) { :published }
  let!(:session) { create(:session, intervention_id: intervention.id) }
  let!(:invitation_email) { 'a@a.com' }
  let!(:params) do
    {
      invitations: [
        {
          emails: [invitation_email, participant.email],
          target_id: intervention.id,
          target_type: 'intervention'
        }
      ]
    }
  end
  let(:request) { post v1_intervention_invitations_path(intervention_id: intervention.id), params: params, headers: user.create_new_auth_token }

  context 'create intervention invitation' do
    context 'when intervention is published' do
      before do
        request
      end

      it 'return correct http status' do
        expect(response).to have_http_status(:created)
      end

      it 'return correct response data' do
        expect(json_response['data'].size).to be(2)
      end

      it 'create correct intervention invitation' do
        expect(intervention.reload.invitations.map(&:email)).to match_array([invitation_email, participant.email])
      end
    end

    context 'when current user is collaborator' do
      let!(:intervention) { create(:flexible_order_intervention) }
      let!(:intervention_status) { :draft }
      let!(:collaborator) { create(:collaborator, intervention: intervention, user: create(:user, :researcher, :confirmed), view: true, edit: false) }
      let(:user) { collaborator.user }

      before { request }

      it {
        expect(response).to have_http_status(:forbidden)
      }
    end

    %w[draft closed archived].each do |status|
      context "when intervention is #{status}" do
        let!(:intervention_status) { status.to_sym }

        before do
          request
        end

        it 'returns correct http status' do
          expect(response).to have_http_status(:not_acceptable)
        end
      end
    end

    context 'when intervention has access for only invitated participants' do
      let!(:intervention) { create(:flexible_order_intervention, status: intervention_status, user_id: user.id, shared_to: 'invited') }

      before do
        request
      end

      it 'invited emails should be on the list with granted access to intervention' do
        expect(intervention.reload.intervention_accesses.map(&:email)).to match_array([invitation_email, participant.email])
      end
    end

    context 'when it is a non-module intervention' do
      let!(:intervention) { create(:intervention, user: user, status: 'published') }

      it 'returns correct HTTP status (Unprocessable Entity)' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  context 'intervention in the organization' do
    let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
    let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
    let!(:health_clinic1) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }
    let!(:health_clinic2) { create(:health_clinic, name: 'Health Clinic 2', health_system: health_system) }
    let!(:params) do
      {
        invitations:
          [{
            health_clinic_id: health_clinic1.id,
            emails: %w[test1@dom.com test2@com.com],
            target_id: intervention.id,
            target_type: 'intervention'
          },
           {
             health_clinic_id: health_clinic2.id,
             emails: %w[test3@dom.com test4@com.com],
             target_id: intervention.id,
             target_type: 'intervention'
           }]
      }
    end

    context 'when user has permission' do
      context 'when intervention is published' do
        before do
          request
        end

        it 'returns correct http status' do
          expect(response).to have_http_status(:created)
        end

        it 'returns correct response data' do
          expect(json_response['data'].size).to eq(4)
        end

        it 'create correct intervention invites' do
          expect(intervention.reload.invitations.map(&:email)).to match_array(%w[test1@dom.com test2@com.com test3@dom.com
                                                                                 test4@com.com])
          expect(intervention.reload.invitations.map(&:health_clinic_id).uniq).to match_array([health_clinic1.id,
                                                                                               health_clinic2.id])
        end
      end

      %w[draft closed archived].each do |status|
        context "when intervention is #{status}" do
          let!(:intervention_status) { status.to_sym }

          before do
            request
          end

          it 'returns correct http status' do
            expect(response).to have_http_status(:not_acceptable)
          end
        end
      end
    end
  end

  context 'create session invitation' do
    let!(:intervention) { create(:intervention, status: intervention_status, user_id: user.id, quick_exit: true, shared_to: 'registered') }
    let!(:session) { create(:session, intervention_id: intervention.id) }
    let!(:invitation_email) { 'a@a.com' }
    let!(:params) do
      {
        invitations: [
          {
            target_id: session.id,
            target_type: 'session',
            emails: [invitation_email, participant.email]
          }
        ]
      }
    end

    context 'create session invitation' do
      context 'when intervention is published' do
        before do
          request
        end

        it 'returns correct http status' do
          expect(response).to have_http_status(:created)
        end

        it 'returns correct response data' do
          expect(json_response['data'].size).to be(2)
        end

        it 'creates correct session invites' do
          expect(session.reload.invitations.map(&:email)).to match_array([invitation_email, participant.email])
        end

        it 'set correct quick_exit_enabled for user' do
          expect(participant.reload.quick_exit_enabled).to be true
          expect(User.find_by(email: invitation_email).reload.quick_exit_enabled).to be true
        end

        context 'when session has access for only invitated participants' do
          let!(:intervention) { create(:intervention, status: intervention_status, user_id: user.id, quick_exit: true, shared_to: 'invited') }

          it 'invited emails should be on the list with granted access to intervention' do
            expect(intervention.reload.intervention_accesses.map(&:email)).to match_array([invitation_email, participant.email])
          end
        end
      end

      context 'UserIntervention' do
        it 'create user_intervention after invite' do
          expect { request }.to change(UserIntervention, :count).by(2)
        end
      end

      %w[draft closed archived].each do |status|
        context "when intervention is #{status}" do
          let!(:intervention_status) { status.to_sym }

          before do
            request
          end

          it 'returns correct http status' do
            expect(response).to have_http_status(:not_acceptable)
          end
        end
      end

      context 'Anyone with the link invitations' do
        let!(:intervention) { create(:intervention, user: user, status: :published, quick_exit: true, shared_to: :anyone) }
        let!(:non_existing_emails) { %w[mike-wazowski@gmail.com fred-flinstone@test.pl] }
        let!(:params) do
          {
            invitations: [{
              target_id: session.id,
              target_type: 'session',
              emails: [invitation_email, participant.email, *non_existing_emails]
            }]
          }
        end

        before { request }

        it 'correctly creates invitations' do
          expect(json_response['data'].map { |hash| hash['attributes']['email'] }).to include(*non_existing_emails)
        end
      end
    end
  end

  context 'session in the organization' do
    let!(:organization) { create(:organization, :with_organization_admin, :with_e_intervention_admin) }
    let!(:health_system) { create(:health_system, name: 'Gotham Health System', organization: organization) }
    let!(:health_clinic1) { create(:health_clinic, name: 'Health Clinic 1', health_system: health_system) }
    let!(:health_clinic2) { create(:health_clinic, name: 'Health Clinic 2', health_system: health_system) }
    let!(:intervention) { create(:intervention, status: intervention_status, shared_to: 'registered', organization: organization, user: user) }
    let(:session) { create(:session, intervention_id: intervention.id) }
    let(:params) do
      {
        invitations:
          [{
             health_clinic_id: health_clinic1.id,
             emails: %w[test1@dom.com test2@com.com],
             target_id: session.id,
             target_type: 'session'
           },
           {
             health_clinic_id: health_clinic2.id,
             emails: %w[test3@dom.com test4@com.com],
             target_id: session.id,
             target_type: 'session'
           }]
      }
    end

    context 'when user has permission' do
      context 'when intervention is published' do
        before do
          request
        end

        it 'invitations has information about health clinics' do
          expect(session.reload.invitations.map(&:health_clinic_id).uniq).to match_array([health_clinic1.id, health_clinic2.id])
        end

        it 'returns correct http status' do
          expect(response).to have_http_status(:created)
        end

        it 'returns correct response data' do
          expect(json_response['data'].size).to eq(4)
        end

        it 'create correct session invites' do
          expect(session.reload.invitations.map(&:email)).to match_array(%w[test1@dom.com test2@com.com test3@dom.com test4@com.com])
        end
      end

      %w[draft closed archived].each do |status|
        context "when intervention is #{status}" do
          let!(:intervention_status) { status.to_sym }

          before do
            request
          end

          it 'returns correct http status' do
            expect(response).to have_http_status(:not_acceptable)
          end
        end
      end
    end
  end
end
