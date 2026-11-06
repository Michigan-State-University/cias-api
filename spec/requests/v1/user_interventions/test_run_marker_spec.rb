# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'test-run marker on POST /v1/user_interventions', type: :request do
  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }

  let(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let(:minted) { V1::TestRuns::LinkToken.mint(intervention.id, researcher.id) }
  let(:token) { minted.token }

  def perform_request(override_token = token, extra = {})
    post v1_user_interventions_path,
         params: { user_intervention: { intervention_id: intervention.id } }
           .merge(test_link_token: override_token).compact.merge(extra)
  end

  def created_guest
    User.limit_to_roles(%w[guest]).order(:created_at, :id).last
  end

  # The concern's rescue is belt-and-braces nothing else falsifies — reverting it leaves every other example green.
  context 'when the marker raises' do
    before { allow(V1::TestRuns::MarkGuest).to receive(:call).and_raise(StandardError, 'boom') }

    it 'still completes the fill' do
      perform_request

      expect(response).to have_http_status(:ok)
    end

    it 'leaves the guest unmarked' do
      perform_request

      expect(created_guest.test_run).to be(false)
    end
  end

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
  end

  context 'without a token' do
    let(:token) { nil }

    before { perform_request }

    it { expect(response).to have_http_status(:ok) }

    it 'leaves the guest unmarked' do
      expect(created_guest.test_run).to be(false)
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
    before do
      perform_request(nil, test_run: true, user_intervention: { intervention_id: intervention.id, test_run: true })
    end

    it 'ignores it entirely' do
      expect(response).to have_http_status(:ok)
      expect(created_guest.test_run).to be(false)
    end
  end

  # Regression: the marker hung off guest resolution, so a token on any GET dragged `params.require` in and returned 400.
  describe 'GET /v1/user_interventions carrying a test_link_token' do
    let(:headers) { researcher.create_new_auth_token }

    it 'still succeeds with a valid token' do
      get v1_user_interventions_path, params: { test_link_token: token }, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it 'still succeeds with a garbage token' do
      get v1_user_interventions_path, params: { test_link_token: 'not-a-token' }, headers: headers

      expect(response).to have_http_status(:ok)
    end

    it 'leaves the link able to mark the fill that follows' do
      get v1_user_interventions_path, params: { test_link_token: token }, headers: headers
      perform_request

      expect(created_guest.test_run).to be(true)
    end
  end

  context 'when authorization rejects the fill' do
    let(:intervention) { create(:intervention, user: researcher, status: :draft, shared_to: :anyone) }

    before { perform_request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'marks nobody' do
      expect(User.limit_to_roles(%w[guest]).where(test_run: true)).to be_empty
    end

    it 'leaves the link usable once the intervention is published' do
      intervention.update!(status: :published)
      perform_request

      expect(response).to have_http_status(:ok)
      expect(created_guest.test_run).to be(true)
    end
  end

  context 'when an authenticated participant presents a valid token' do
    let_it_be(:participant) { create(:user, :confirmed, :participant) }

    before do
      post v1_user_interventions_path,
           params: { user_intervention: { intervention_id: intervention.id }, test_link_token: token },
           headers: participant.create_new_auth_token
    end

    it 'never marks a registered participant' do
      expect(response).to have_http_status(:ok)
      expect(participant.reload.test_run).to be(false)
    end
  end

  # `meta.test_run` answers "is *this* fill test data?" — reporting true for another intervention promises a deletion that never comes.
  describe 'meta.test_run scoping' do
    let(:other_intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
    # Reuse the guest the marking request created, the way a browser would.
    let(:guest_headers) { @guest_headers }

    def perform_other_request(override_token = nil)
      post v1_user_interventions_path,
           params: { user_intervention: { intervention_id: other_intervention.id } }
             .merge(test_link_token: override_token).compact,
           headers: guest_headers
    end

    before do
      perform_request
      @marked_guest = created_guest
      @guest_headers = @marked_guest.create_new_auth_token
    end

    it 'reports the marking fill as test data' do
      expect(@marked_guest.reload.test_run).to be(true)
    end

    it 'reports false for a tokenless fill of a different intervention' do
      perform_other_request

      expect(json_response['meta']['test_run']).to be(false)
    end

    it "reports false for a different intervention even with that intervention's own token" do
      other_token = V1::TestRuns::LinkToken.mint(other_intervention.id, researcher.id).token
      perform_other_request(other_token)

      # `markable?` refuses an already-marked guest, so this fill is genuinely not test data.
      expect(json_response['meta']['test_run']).to be(false)
    end

    # Stops anyone simplifying this back to a bare `test_run?`.
    it 'still reports true for a later tokenless fill of the marked intervention' do
      post v1_user_interventions_path,
           params: { user_intervention: { intervention_id: intervention.id } },
           headers: guest_headers

      expect(json_response['meta']['test_run']).to be(true)
    end
  end

  describe 'when the marker write fails after assigning' do
    before do
      # Only the marker write — the controller also calls `update!` for `quick_exit_enabled`.
      allow_any_instance_of(User).to receive(:update!).and_wrap_original do |m, *args|
        next m.call(*args) unless args.first.is_a?(Hash) && args.first.key?(:test_run)

        m.receiver.assign_attributes(*args)
        raise ActiveRecord::RecordInvalid, m.receiver
      end
      perform_request
    end

    it 'reports the fill as not test data' do
      expect(json_response['meta']['test_run']).to be(false)
    end

    it 'leaves the guest unmarked in the database' do
      expect(created_guest.reload.test_run).to be(false)
    end
  end
end
