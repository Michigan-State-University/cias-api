# frozen_string_literal: true

RSpec.describe 'GET /v1/cat_mh/populations', type: :request do
  let_it_be(:user) { create(:user, :confirmed, :admin) }
  let_it_be(:headers) { user.create_new_auth_token }
  let_it_be(:populations) do
    CatMhPopulation.create!([{ name: 'General' }, { name: 'Perinatal' }, { name: 'Criminal justice' }])
  end

  let(:request) do
    get v1_cat_mh_populations_path, headers: headers
  end

  context 'returns proper data' do
    before { request }

    it 'returns proper data amount' do
      expect(json_response['data'].size).to eq(populations.size)
    end

    it 'returns proper HTTP code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns proper data' do
      expect(json_response['data'].map { |h| h['id'].to_i }).to match_array(populations.pluck(:id))
    end
  end

  context 'unauthorized user' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:headers) { user.create_new_auth_token }
    let(:request) { get v1_cat_mh_populations_path, headers: headers }

    it 'returns correct HTTP code (Forbidden)' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end
end
