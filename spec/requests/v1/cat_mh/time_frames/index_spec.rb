# frozen_string_literal: true

RSpec.describe 'GET /v1/cat_mh/time_frames', type: :request do
  let_it_be(:user) { create(:user, :confirmed, :admin) }
  let_it_be(:headers) { user.create_new_auth_token }
  let_it_be(:time_frames) do
    CatMhTimeFrame.create([{ timeframe_id: 1, description: 'Past hour', short_name: '1h' },
                           { timeframe_id: 2, description: 'Lifetime', short_name: 'life' }])
  end

  let(:request) do
    get v1_cat_mh_time_frames_path, headers: headers
  end

  context 'returns proper data' do
    before { request }

    it 'returns proper data size' do
      expect(json_response['data'].size).to eq(time_frames.size)
    end

    it 'returns proper data' do
      expect(json_response['data'].map { |h| h['id'].to_i }).to match_array(time_frames.pluck(:id))
    end

    it 'returns proper HTTP Status code (OK)' do
      expect(response).to have_http_status(:ok)
    end
  end

  context 'unauthorized user' do
    let(:user) { create(:user, :confirmed, :participant) }
    let(:headers) { user.create_new_auth_token }
    let(:request) { get v1_cat_mh_time_frames_path, headers: headers }

    it 'returns correct HTTP code (Forbidden)' do
      request
      expect(response).to have_http_status(:forbidden)
    end
  end
end
