# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/predefined_participants/verify', type: :request do
  let(:request) do
    post v1_verify_predefined_participant_path, params: params
  end
  let(:user) { create(:user, :predefined_participant, :with_phone) }
  let(:params) do
    {
      slug: user.predefined_user_parameter.slug
    }
  end

  it 'when the slug is correct but intervention is draft' do
    request
    expect(response).to have_http_status(:bad_request)
    expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_DRAFT' } })
  end

  context 'when intervention is paused' do
    before do
      user.predefined_user_parameter.intervention.update!(status: :paused)
    end

    it 'returns correct status and error message' do
      request
      expect(response).to have_http_status(:bad_request)
      expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_PAUSED' } })
    end
  end

  context 'when intervention is closed/archived' do
    before do
      user.predefined_user_parameter.intervention.update!(status: :closed)
    end

    it 'returns correct status and error message' do
      request
      expect(response).to have_http_status(:bad_request)
      expect(json_response).to include({ 'message' => 'Intervention is not available', 'details' => { 'reason' => 'INTERVENTION_CLOSED' } })
    end
  end

  context 'when intervention is published' do
    before do
      user.predefined_user_parameter.intervention.published!
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'signs the participant in through the headers and keeps the tokens out of the body' do
      request
      expect(response.headers['access-token']).to be_present
      expect(response.headers['uid']).to eq(user.uid)
      expect(response.body).not_to include(response.headers['access-token'])
    end

    it 'return correct body' do
      request
      expect(json_response.keys).to match_array(%w[user redirect_data])
    end

    it 'return data about the user' do
      request
      expect(json_response['user'].keys).to match_array(%w[id type attributes])
      expect(json_response['user']['attributes'].keys).to match_array(%w[id
                                                                         email
                                                                         full_name
                                                                         first_name
                                                                         last_name
                                                                         description
                                                                         sms_notification
                                                                         time_zone
                                                                         active
                                                                         roles
                                                                         avatar_url
                                                                         phone
                                                                         team_id
                                                                         admins_team_ids
                                                                         feedback_completed
                                                                         email_notification
                                                                         organizable_id
                                                                         quick_exit_enabled
                                                                         team_name
                                                                         health_clinics_ids])
    end

    it 'return information needed to redirect the user' do
      request
      expect(json_response['redirect_data'].keys).to match_array(%w[intervention_id session_id health_clinic_id multiple_fill_session_available
                                                                    user_intervention_id lang intervention_type ra_session_pending])
    end
  end

  context 'when slug is incorrect' do
    let(:params) do
      {
        slug: 'wrong_slug'
      }
    end

    it 'when the slug is correct but intervention is draft' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when a participant tries to perform a request' do
    let(:participant) { create(:user, :participant, :confirmed) }
    let!(:headers) { participant.create_new_auth_token }
    let(:request) do
      post v1_verify_predefined_participant_path, params: params, headers: headers
    end

    it 'return correct status' do
      request
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'first_opened_at' do
    include ActiveJob::TestHelper
    include ActiveSupport::Testing::TimeHelpers

    let(:participant) { create(:user, :predefined_participant, :with_phone) }
    let(:predefined_user_parameter) { participant.predefined_user_parameter }
    let(:intervention) { predefined_user_parameter.intervention }
    let(:slug) { predefined_user_parameter.slug }
    let(:opened_at) { Time.zone.local(2026, 11, 2, 9, 0, 0) }

    def open_link
      post v1_verify_predefined_participant_path, params: { slug: slug }
    end

    describe 'an unavailable intervention does not record an open' do
      %i[draft paused closed].each do |status|
        context "when the intervention is #{status}" do
          before { intervention.update!(status: status) }

          it "answers 400 and leaves first_opened_at empty for #{status}" do
            travel_to(opened_at) { open_link }

            expect(response).to have_http_status(:bad_request)
            expect(json_response['details']['reason']).to eq("INTERVENTION_#{status.to_s.upcase}")
            expect(predefined_user_parameter.reload.first_opened_at).to be_nil
          end

          it "keeps the participant unstamped after repeated attempts while #{status}" do
            travel_to(opened_at) { 2.times { open_link } }

            expect(predefined_user_parameter.reload.first_opened_at).to be_nil
          end
        end
      end

      context 'when the intervention is paused and then resumed' do
        before { intervention.update!(status: :paused) }

        it 'stamps only once the intervention is published again' do
          travel_to(opened_at) { open_link }
          expect(predefined_user_parameter.reload.first_opened_at).to be_nil

          intervention.update!(status: :published)
          travel_to(opened_at + 1.day) { open_link }

          expect(predefined_user_parameter.reload.first_opened_at).to eq(opened_at + 1.day)
        end
      end

      context 'when the intervention is published' do
        before { intervention.update!(status: :published) }

        it 'stamps first_opened_at on the published path' do
          travel_to(opened_at) { open_link }

          expect(response).to have_http_status(:ok)
          expect(predefined_user_parameter.reload.first_opened_at).to eq(opened_at)
        end
      end
    end

    describe 'the first open is kept through the HTTP endpoint' do
      before { intervention.update!(status: :published) }

      it 'does not move the stamp on a second open' do
        travel_to(opened_at) { open_link }
        travel_to(opened_at + 3.days) { open_link }

        expect(predefined_user_parameter.reload.first_opened_at).to eq(opened_at)
      end

      it 'does not stamp on an unknown slug' do
        travel_to(opened_at) { post v1_verify_predefined_participant_path, params: { slug: 'wrong_slug' } }

        expect(response).to have_http_status(:not_found)
        expect(predefined_user_parameter.reload.first_opened_at).to be_nil
      end
    end

    describe 'research assistant and bulk import paths never stamp' do
      let(:researcher) { create(:user, :researcher, :confirmed) }
      let(:published_intervention) { create(:intervention, :published, user: researcher) }
      let!(:ra_session) { create(:ra_session, intervention: published_intervention) }
      let(:ra_participant) { create(:user, :confirmed, :predefined_participant) }
      let!(:ra_parameter) { create(:predefined_user_parameter, intervention: published_intervention, user: ra_participant) }
      let(:headers) { researcher.create_new_auth_token }

      context 'when a researcher fulfils the RA session for a participant' do
        before do
          travel_to(opened_at) { post "/v1/predefined_participants/#{ra_parameter.slug}/ra_session", headers: headers }
        end

        it 'answers ok' do
          expect(response).to have_http_status(:ok)
        end

        it 'leaves first_opened_at empty' do
          expect(ra_parameter.reload.first_opened_at).to be_nil
        end

        it 'stamps only when the participant opens the link themselves' do
          travel_to(opened_at + 1.day) { post v1_verify_predefined_participant_path, params: { slug: ra_parameter.slug } }

          expect(ra_parameter.reload.first_opened_at).to eq(opened_at + 1.day)
        end
      end

      context 'when a researcher uses the manage endpoints' do
        let(:managed) { create(:user, :confirmed, :predefined_participant) }
        let!(:managed_parameter) { create(:predefined_user_parameter, intervention: published_intervention, user: managed) }

        it 'does not stamp on create, update, show, index and send_email_invitation' do
          travel_to(opened_at) do
            post v1_intervention_predefined_participants_path(intervention_id: published_intervention.id),
                 params: { predefined_user: { first_name: 'Ada', last_name: 'Lovelace', email: 'ada@example.test' } }, headers: headers, as: :json
            patch v1_intervention_predefined_participant_path(intervention_id: published_intervention.id, id: managed.id),
                  params: { predefined_user: { first_name: 'Grace' } }, headers: headers, as: :json
            get v1_intervention_predefined_participant_path(intervention_id: published_intervention.id, id: managed.id), headers: headers
            get v1_intervention_predefined_participants_path(intervention_id: published_intervention.id), headers: headers
          end

          expect(PredefinedUserParameter.where(intervention_id: published_intervention.id).pluck(:first_opened_at)).to all(be_nil)
        end
      end

      context 'when participants arrive through bulk import' do
        let(:participants) do
          [
            { first_name: 'Alice', last_name: 'Smith', email: 'import-a@example.test' },
            { first_name: 'Bob', last_name: 'Jones', email: 'import-b@example.test' }
          ]
        end

        before do
          travel_to(opened_at) do
            perform_enqueued_jobs do
              post bulk_create_v1_intervention_predefined_participants_path(intervention_id: published_intervention.id),
                   params: { predefined_users: { participants: participants } }, headers: headers, as: :json
            end
          end
        end

        it 'imports the participants' do
          expect(response).to have_http_status(:accepted)
          expect(User.where(email: %w[import-a@example.test import-b@example.test]).count).to eq(2)
        end

        it 'leaves first_opened_at empty for every imported participant' do
          imported = PredefinedUserParameter.where(user: User.where(email: %w[import-a@example.test import-b@example.test]))

          expect(imported.count).to eq(2)
          expect(imported.pluck(:first_opened_at)).to all(be_nil)
        end

        it 'stamps an imported participant only when they open the link' do
          imported = PredefinedUserParameter.find_by!(user: User.find_by!(email: 'import-a@example.test'))
          travel_to(opened_at + 2.days) { post v1_verify_predefined_participant_path, params: { slug: imported.slug } }

          expect(imported.reload.first_opened_at).to eq(opened_at + 2.days)
        end
      end

      context 'with researcher reads and writes on the participant' do
        let(:participant) { create(:user, :confirmed, :predefined_participant, :with_phone) }
        let!(:parameter) { create(:predefined_user_parameter, intervention: published_intervention, user: participant) }

        it 'index, show and update leave first_opened_at nil' do
          get v1_intervention_predefined_participants_path(intervention_id: published_intervention.id), headers: headers
          get v1_intervention_predefined_participant_path(intervention_id: published_intervention.id, id: participant.id), headers: headers
          patch v1_intervention_predefined_participant_path(intervention_id: published_intervention.id, id: participant.id),
                params: { predefined_user: { first_name: 'Changed' } }, headers: headers

          expect(response).to have_http_status(:ok)
          expect(parameter.reload.first_opened_at).to be_nil
        end

        it 'send_sms_invitation leaves first_opened_at nil' do
          allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true)
          parameter.update!(sms_invitation_sent_at: 1.day.ago)

          post send_sms_invitation_v1_intervention_predefined_participant_path(intervention_id: published_intervention.id, id: participant.id),
               headers: headers

          expect(response).to have_http_status(:ok)
          expect(parameter.reload.first_opened_at).to be_nil
        end
      end

      context 'when verify is rejected before reaching the service' do
        let(:other_participant) { create(:user, :participant, :confirmed) }

        it 'an unauthorized caller does not stamp the participant' do
          intervention.published!
          post v1_verify_predefined_participant_path, params: { slug: predefined_user_parameter.slug },
                                                      headers: other_participant.create_new_auth_token

          expect(response).to have_http_status(:unauthorized)
          expect(predefined_user_parameter.reload.first_opened_at).to be_nil
        end
      end
    end
  end
end
