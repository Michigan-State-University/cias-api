# frozen_string_literal: true

RSpec.describe 'POST /v1/interventions/:intervention_id/predefined_participants/sms_campaigns/:id/cancel',
               type: :request do
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let!(:intervention) { create(:intervention, :published, user: researcher) }
  let!(:campaign) { create(:pdp_sms_campaign, :scheduled, intervention: intervention, scheduled_at: 2.days.from_now) }
  let(:campaign_id) { campaign.id }
  let(:intervention_id) { intervention.id }
  let(:current_user) { researcher }
  let(:headers) { current_user.create_new_auth_token }
  let(:path) { "/v1/interventions/#{intervention_id}/predefined_participants/sms_campaigns/#{campaign_id}/cancel" }
  let(:request) { post path, as: :json, headers: headers }

  after { delete_pushed_jobs }

  # Proves the cancel route is live (owner cancels a throw-away campaign), so a 404/403 below cannot be a missing-route 404.
  def prove_route_live
    probe = create(:pdp_sms_campaign, :scheduled, intervention: intervention, kind: 'manual_reminder', scheduled_at: 2.days.from_now)
    post "/v1/interventions/#{intervention.id}/predefined_participants/sms_campaigns/#{probe.id}/cancel",
         as: :json, headers: researcher.create_new_auth_token
    expect(response).to have_http_status(:success)
  end

  describe 'happy path and scoping' do
    it 'cancels a scheduled campaign of the intervention (2xx) and persists the status' do
      request
      expect(response).to have_http_status(:success)
      expect(campaign.reload.status).to eq('cancelled')
    end

    it 'removes the scheduled Sidekiq job of that campaign' do
      jid = push_campaign_job(campaign.id)
      request
      expect(jid_scheduled?(jid)).to be(false)
    end

    context 'when the campaign belongs to ANOTHER intervention of the same researcher' do
      let(:other_intervention) { create(:intervention, :published, user: researcher) }
      let!(:foreign_campaign) { create(:pdp_sms_campaign, :scheduled, intervention: other_intervention, scheduled_at: 2.days.from_now) }
      let(:campaign_id) { foreign_campaign.id }

      before { prove_route_live }

      it 'answers 404, not 200, and leaves the campaign scheduled' do
        request
        expect(response).to have_http_status(:not_found)
        expect(foreign_campaign.reload.status).to eq('scheduled')
      end

      it 'does not touch the job of that campaign' do
        jid = push_campaign_job(foreign_campaign.id)
        request
        expect(jid_scheduled?(jid)).to be(true)
      end
    end

    context 'when the campaign belongs to an intervention of ANOTHER researcher' do
      let(:foreign_campaign) { create(:pdp_sms_campaign, :scheduled, scheduled_at: 2.days.from_now) }
      let(:campaign_id) { foreign_campaign.id }

      before { prove_route_live }

      it 'answers 404 and leaves the campaign scheduled' do
        request
        expect(response).to have_http_status(:not_found)
        expect(foreign_campaign.reload.status).to eq('scheduled')
      end
    end

    context 'when the campaign id does not exist' do
      let(:campaign_id) { SecureRandom.uuid }

      before { prove_route_live }

      it 'answers 404' do
        request
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'over HTTP: illegal state transition' do
    %w[sending sent failed cancelled skipped].each do |status|
      context "when the campaign is #{status}" do
        before { campaign.update_columns(status: status) }

        it 'answers 409 and leaves the status unchanged' do
          request
          expect(response).to have_http_status(:conflict)
          expect(response.body).not_to match(/PG::|ActiveRecord|index_/)
          expect(campaign.reload.status).to eq(status)
        end
      end
    end
  end

  describe 'gates identical to create' do
    describe 'other researcher / other role (shared example)' do
      before { prove_route_live }

      it_behaves_like 'users without access'
    end

    context 'without a token' do
      let(:headers) { {} }

      it 'answers 401 and leaves the campaign scheduled' do
        request
        expect(response).to have_http_status(:unauthorized)
        expect(campaign.reload.status).to eq('scheduled')
      end
    end

    context 'when a collaborator with edit: true is NOT the current editor' do
      let(:collaborator_user) { create(:user, :researcher, :confirmed) }
      let(:current_user) { collaborator_user }

      before do
        prove_route_live
        create(:collaborator, intervention: intervention, user: collaborator_user, edit: true, view: true)
        intervention.update!(current_editor: researcher)
      end

      it 'answers 403 and leaves the campaign scheduled' do
        request
        expect(response).to have_http_status(:forbidden)
        expect(campaign.reload.status).to eq('scheduled')
      end

      it 'does not touch the Sidekiq job' do
        jid = push_campaign_job(campaign.id)
        request
        expect(jid_scheduled?(jid)).to be(true)
      end
    end

    context 'when a collaborator with edit: true IS the current editor (control)' do
      let(:collaborator_user) { create(:user, :researcher, :confirmed) }
      let(:current_user) { collaborator_user }

      before do
        create(:collaborator, intervention: intervention, user: collaborator_user, edit: true, view: true)
        intervention.update!(current_editor: collaborator_user)
      end

      it 'cancels the campaign' do
        request
        expect(response).to have_http_status(:success)
        expect(campaign.reload.status).to eq('cancelled')
      end
    end

    context 'when the participant role tries to cancel (role check is server-side)' do
      let(:current_user) { create(:user, :participant, :confirmed) }

      it 'answers 403 and leaves the campaign scheduled' do
        request
        expect(response).to have_http_status(:forbidden)
        expect(campaign.reload.status).to eq('scheduled')
      end
    end
  end
end
