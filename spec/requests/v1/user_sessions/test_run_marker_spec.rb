# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'test-run marker on the public user_session entry points', type: :request do
  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }

  let(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let(:session) { create(:session, intervention: intervention) }
  let(:minted) { V1::TestRuns::LinkToken.mint(intervention.id, researcher.id) }
  let(:token) { minted.token }
  let(:params) { { user_session: { session_id: session.id }, test_link_token: token }.compact }

  def created_guest
    User.limit_to_roles(%w[guest]).order(:created_at, :id).last
  end

  shared_examples 'a public fill entry point' do
    context 'with a valid test-link token' do
      before { perform_request }

      it { expect(response).to have_http_status(:ok) }

      it 'persists the guest with test_run set' do
        expect(created_guest.test_run).to be(true)
      end

      it 'records the intervention the marker covers' do
        expect(created_guest.test_run_intervention_id).to eq(intervention.id)
      end

      it 'records the researcher whose link did the marking' do
        expect(created_guest.test_run_marked_by_id).to eq(researcher.id)
      end

      # The client cannot infer this: the backend fails open, so a refused marker looks identical on the wire.
      it 'tells the client the fill is test data' do
        expect(json_response['meta']['test_run']).to be(true)
      end
    end

    context 'without a token' do
      let(:token) { nil }

      before { perform_request }

      it { expect(response).to have_http_status(:ok) }

      it 'leaves the guest unmarked' do
        expect(created_guest.test_run).to be(false)
      end

      it 'tells the client the fill is not test data' do
        expect(json_response['meta']['test_run']).to be(false)
      end
    end

    context 'with an expired token' do
      before do
        expired = minted.token
        Timecop.travel(V1::TestRuns::LinkToken.ttl.from_now + 1.minute) { perform_request(expired) }
      end

      it 'still completes the fill' do
        expect(response).to have_http_status(:ok)
      end

      it 'leaves the guest unmarked' do
        expect(created_guest.test_run).to be(false)
      end
    end

    context 'with a tampered token' do
      let(:token) { minted.token.sub(/.\z/) { |char| char == 'a' ? 'b' : 'a' } }

      before { perform_request }

      it 'still completes the fill' do
        expect(response).to have_http_status(:ok)
      end

      it 'leaves the guest unmarked' do
        expect(created_guest.test_run).to be(false)
      end
    end

    context 'with a token minted for a different intervention' do
      let(:token) { V1::TestRuns::LinkToken.mint(create(:intervention, user: researcher).id, researcher.id).token }

      before { perform_request }

      it 'still completes the fill' do
        expect(response).to have_http_status(:ok)
      end

      it 'leaves the guest unmarked' do
        expect(created_guest.test_run).to be(false)
      end
    end

    context 'when the same token is replayed by a second guest' do
      before { perform_request }

      # Deliberate (D8): no ceiling. A one-shot nonce and a cap of five each recorded a later test run as a real participant.
      it 'marks the second guest as well' do
        first_guest = created_guest
        perform_request

        expect(created_guest).not_to eq(first_guest)
        expect(first_guest.reload.test_run).to be(true)
        expect(created_guest.test_run).to be(true)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the client supplies a raw test_run flag instead of a token' do
      let(:token) { nil }

      before { perform_request(nil, test_run: true, user_session: { session_id: session.id, test_run: true }) }

      it 'ignores it entirely' do
        expect(response).to have_http_status(:ok)
        expect(created_guest.test_run).to be(false)
      end
    end
  end

  describe 'POST /v1/user_sessions' do
    def perform_request(override_token = token, extra = {})
      post v1_user_sessions_path, params: params.merge(test_link_token: override_token).compact.merge(extra)
    end

    it_behaves_like 'a public fill entry point'
  end

  describe 'POST /v1/fetch_or_create_user_sessions' do
    def perform_request(override_token = token, extra = {})
      post v1_fetch_or_create_user_sessions_path, params: params.merge(test_link_token: override_token).compact.merge(extra)
    end

    it_behaves_like 'a public fill entry point'
  end

  describe 'POST /v1/user_sessions rejected by authorization' do
    let(:intervention) { create(:intervention, user: researcher, status: :draft, shared_to: :anyone) }

    before { post v1_user_sessions_path, params: params }

    it { expect(response).to have_http_status(:forbidden) }

    it 'marks nobody' do
      expect(User.limit_to_roles(%w[guest]).where(test_run: true)).to be_empty
    end

    it 'leaves the link usable once the intervention is published' do
      intervention.update!(status: :published)
      post v1_user_sessions_path, params: params

      expect(response).to have_http_status(:ok)
      expect(created_guest.test_run).to be(true)
    end
  end

  # Regression: the marker hung off guest resolution, so a token on any GET dragged `params.require` in and returned 400.
  describe 'GET /v1/user_sessions/:id/ra_show carrying a test_link_token' do
    let(:ra_intervention) { create(:intervention, :published, user: researcher) }
    let!(:ra_session) { create(:ra_session, intervention: ra_intervention) }
    let(:participant) { create(:user, :confirmed, :predefined_participant) }
    let(:user_intervention) { create(:user_intervention, user: participant, intervention: ra_intervention) }
    let!(:ra_user_session) do
      create(:ra_user_session, session: ra_session, user: participant,
                               user_intervention: user_intervention, fulfilled_by: researcher)
    end
    let(:headers) { researcher.create_new_auth_token }

    def ra_show(query_token)
      get "/v1/user_sessions/#{ra_user_session.id}/ra_show", params: { test_link_token: query_token }, headers: headers
    end

    it 'still succeeds with a valid token' do
      ra_show(V1::TestRuns::LinkToken.mint(ra_intervention.id, researcher.id).token)

      expect(response).to have_http_status(:ok)
    end

    it 'still succeeds with a garbage token' do
      ra_show('not-a-token')

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'a guest created by an earlier, tokenless request' do
    it 'is still marked when it presents the token' do
      post v1_user_interventions_path, params: { user_intervention: { intervention_id: intervention.id } }
      guest = created_guest
      guest_headers = response.headers.slice('access-token', 'client', 'uid', 'token-type', 'expiry')

      expect(guest.test_run).to be(false)

      post v1_user_sessions_path, params: params, headers: guest_headers

      expect(response).to have_http_status(:ok)
      expect(created_guest).to eq(guest)
      expect(guest.reload.test_run).to be(true)
    end
  end

  # `filter_parameters` redacts log *output* only. `Log::UserRequest` persists params into `user_log_requests`,
  # which `audited` copies into `audits` — two permanent stores. The token is a credential and must reach neither.
  describe 'request logging' do
    include ActiveJob::TestHelper

    it 'does not persist the raw test-link token' do
      post v1_user_sessions_path, params: params.merge(test_link_token: token)

      logged = enqueued_jobs.select { |j| j['job_class'] == 'LogJobs::UserRequest' }
      expect(logged).not_to be_empty
      logged.each do |job|
        expect(job.to_json).not_to include(token)
      end
    end
  end
end
