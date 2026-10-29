# frozen_string_literal: true

RSpec.describe 'GET /v1/me', type: :request do
  let(:user) do
    create(:user, :confirmed, :researcher, first_name: 'John', last_name: 'Doe', time_zone: 'Europe/Warsaw')
  end
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_get_user_details_path, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_get_user_details_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  it_behaves_like 'deactivated account'

  context 'when user is signed in' do
    let_it_be(:other_user) { create(:user, :confirmed, :participant) }

    before { request }

    it 'returns correct HTTP status (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns the current user' do
      expect(json_response['data']).to include('id' => user.id, 'type' => 'user')
    end

    it 'returns key attributes of the current user' do
      expect(json_response['data']['attributes']).to include(
        'id' => user.id,
        'email' => user.email,
        'first_name' => 'John',
        'last_name' => 'Doe',
        'full_name' => 'John Doe',
        'time_zone' => 'Europe/Warsaw',
        'roles' => ['researcher'],
        'active' => true
      )
    end

    it 'does not return data of other users' do
      expect(json_response['data']['id']).not_to eq(other_user.id)
      expect(response.body).not_to include(other_user.email)
    end
  end

  %w[admin participant guest team_admin e_intervention_admin health_system_admin].each do |role|
    context "when current user is #{role}" do
      let(:user) { create(:user, :confirmed, role) }

      before { request }

      it 'returns own data with roles' do
        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']).to include('email' => user.email, 'roles' => match_array(user.roles))
        expect(json_response['data']['attributes']['roles']).to include(role)
      end
    end
  end
end
