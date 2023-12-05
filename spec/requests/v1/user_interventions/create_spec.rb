# frozen_string_literal: true

RSpec.describe 'POST /v1/user_interventions', type: :request do
  let!(:user) { create(:user, :admin, :confirmed) }
  let!(:intervention) { create(:flexible_order_intervention, user: user, shared_to: 'registered') }

  let(:params) do
    {
      user_intervention: {
        intervention_id: intervention.id
      }
    }
  end

  let(:request) { post v1_user_interventions_path, headers: user.create_new_auth_token, params: params }

  it_behaves_like 'paused intervention'

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_user_interventions_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'create user intervention' do
    it 'returns correct HTTP status code (OK)' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'return correct data type' do
      request
      expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8')
      expect(json_response.class).to be(Hash)
    end

    it 'save user intervention in db' do
      expect { request }.to change(UserIntervention, :count).by(1)
    end

    context 'when quick_exit is turn on' do
      let!(:intervention) { create(:flexible_order_intervention, user: user, shared_to: 'registered', quick_exit: true) }

      it 'returns correct HTTP status code (OK)' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'save user intervention in db' do
        expect { request }.to change(UserIntervention, :count).by(1)
      end

      it 'set correct flag in user object' do
        request
        expect(user.reload.quick_exit_enabled).to be true
      end
    end
  end

  context 'when user intervention exist in the system' do
    let!(:user_intervention) { create(:user_intervention, intervention_id: intervention.id, user: user) }

    before { request }

    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'return an existing intervention' do
      expect(json_response.class).to be(Hash)
      expect(json_response['data']['id']).to eql(user_intervention.id)
    end

    it 'avoid change UserIntervention.count' do
      expect { request }.to avoid_changing { UserIntervention.count }
    end
  end
end
