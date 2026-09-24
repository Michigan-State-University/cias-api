# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/test_link_tokens/verify', type: :request do
  let_it_be(:researcher) { create(:user, :confirmed, :researcher) }

  let(:intervention) { create(:intervention, user: researcher, status: :published, shared_to: :anyone) }
  let(:minted) { V1::TestRuns::LinkToken.mint(intervention.id, researcher.id) }
  let(:token) { minted.token }
  let(:body) { { test_link_token: token } }

  def perform_request
    post v1_verify_test_link_token_path, params: body
  end

  context 'when the token is live' do
    before { perform_request }

    it { expect(response).to have_http_status(:ok) }

    it 'reports it as valid' do
      expect(json_response).to include('status' => 'valid', 'valid' => true)
    end

    it 'echoes back the intervention the token names' do
      expect(json_response['intervention_id']).to eq(intervention.id)
    end

    it 'does not disclose who minted it' do
      expect(json_response.keys).to contain_exactly('status', 'valid', 'intervention_id')
      expect(response.body).not_to include(researcher.id)
    end
  end

  it 'does not consume the token' do
    3.times { perform_request }

    expect(json_response['status']).to eq('valid')
    expect(V1::TestRuns::LinkToken.verify(token, intervention.id)).to be_present
  end

  it 'writes nothing' do
    intervention

    expect { perform_request }.to avoid_changing(User, :count)
      .and avoid_changing(UserSession, :count)
      .and avoid_changing(UserIntervention, :count)
  end

  # Must be sent as JSON: `ParamsWrapper` only wraps JSON bodies, and the wrapped copy is what escaped the scrub.
  it 'keeps the token out of the persisted request log' do
    logged = nil
    allow(LogJobs::UserRequest).to receive(:perform_later) { |scope| logged = scope }

    post v1_verify_test_link_token_path, params: body.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:ok)
    expect(logged).to be_present
    expect(logged.to_s).not_to include(token)
  end

  context 'when the token has expired' do
    it 'says so, so the page can offer a fresh link rather than a generic error' do
      token = minted.token

      Timecop.travel(V1::TestRuns::LinkToken.ttl.from_now + 1.minute) do
        post v1_verify_test_link_token_path, params: { test_link_token: token }
      end

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('status' => 'expired', 'valid' => false, 'intervention_id' => nil)
    end
  end

  context 'when the token is not one of ours' do
    shared_examples 'reports an invalid token' do
      it 'answers 200 with an invalid verdict and no intervention' do
        perform_request

        expect(response).to have_http_status(:ok)
        expect(json_response).to include('status' => 'invalid', 'valid' => false, 'intervention_id' => nil)
      end
    end

    context 'when the signature was tampered with' do
      let(:token) { minted.token.sub(/.\z/) { |char| char == 'a' ? 'b' : 'a' } }

      it_behaves_like 'reports an invalid token'
    end

    context 'when the payload was tampered with' do
      let(:token) do
        payload, signature = minted.token.split('--')
        forged = Base64.urlsafe_encode64(
          Base64.urlsafe_decode64(payload).sub(intervention.id, SecureRandom.uuid), padding: false
        )
        "#{forged}--#{signature}"
      end

      it_behaves_like 'reports an invalid token'
    end

    context 'when the token is garbage' do
      let(:token) { 'not-a-token' }

      it_behaves_like 'reports an invalid token'
    end

    context 'when the parameter is missing entirely' do
      let(:body) { {} }

      it_behaves_like 'reports an invalid token'
    end

    context 'when the parameter is blank' do
      let(:token) { '' }

      it_behaves_like 'reports an invalid token'
    end
  end

  it 'does not look the intervention up, so it cannot leak whether one exists' do
    unknown_id = SecureRandom.uuid
    orphan = V1::TestRuns::LinkToken.mint(unknown_id, researcher.id)

    post v1_verify_test_link_token_path, params: { test_link_token: orphan.token }

    expect(json_response).to include('status' => 'valid', 'intervention_id' => unknown_id)
  end

  it 'needs no authentication, because the person opening a test link has no session yet' do
    perform_request

    expect(response).not_to have_http_status(:unauthorized)
  end

  it 'ignores the caller identity of a request that happens to carry one' do
    post v1_verify_test_link_token_path, params: body, headers: researcher.create_new_auth_token

    expect(response).to have_http_status(:ok)
    expect(json_response['status']).to eq('valid')
  end
end
