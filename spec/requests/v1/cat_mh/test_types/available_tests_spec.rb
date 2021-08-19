# frozen_string_literal: true

RSpec.describe 'GET /v1/cat_mh/available_test_types', type: :request do
  let_it_be(:user) { create(:user, :confirmed, :admin) }
  let_it_be(:headers) { user.create_new_auth_token }
  let_it_be(:target_population1) { CatMhPopulation.create!(name: 'General') }
  let_it_be(:target_population2) { CatMhPopulation.create!(name: 'Perinatal') }
  let_it_be(:target_population3) { CatMhPopulation.create!(name: 'Criminal justice') }
  let_it_be(:target_language1) { CatMhLanguage.create!(language_id: 1, name: 'English') }
  let_it_be(:target_language2) { CatMhLanguage.create!(language_id: 2, name: 'Spanish') }
  let_it_be(:target_time_frame1) { CatMhTimeFrame.create!(timeframe_id: 1, short_name: '1w', description: 'Past week') }
  let_it_be(:target_time_frame2) { CatMhTimeFrame.create!(timeframe_id: 2, short_name: '1h', description: 'Past Hour') }
  let_it_be(:test_types) do
    CatMhTestType.create!([
                            { cat_mh_population: target_population1, cat_mh_languages: [target_language1], cat_mh_time_frames: [target_time_frame1] },
                            { cat_mh_population: target_population1, cat_mh_languages: [target_language1, target_language2],
                              cat_mh_time_frames: [target_time_frame1, target_time_frame2] },
                            { cat_mh_population: target_population3, cat_mh_languages: [target_language2], cat_mh_time_frames: [target_time_frame2] }
                          ])
  end

  shared_examples 'correct response' do
    it 'returns correct HTTP status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct amount of test types' do
      expect(json_response['data'].size).to eq(1)
    end
  end

  describe 'general population' do
    let(:params) do
      {
        population_id: target_population1.id,
        language_id: target_language2.id,
        time_frame_id: target_time_frame1.id
      }
    end
    let(:request) do
      get v1_cat_mh_available_test_types_path, headers: headers, params: params
    end

    before { request }

    it_behaves_like 'correct response'
  end

  describe 'other populations' do
    let(:params) do
      {
        population_id: target_population3.id,
        language_id: target_language2.id,
        time_frame_id: target_time_frame2.id
      }
    end
    let(:request) do
      get v1_cat_mh_available_test_types_path, headers: headers, params: params
    end

    before { request }

    it_behaves_like 'correct response'
  end

  describe 'missing params' do
    let(:request) do
      get v1_cat_mh_available_test_types_path, headers: headers, params: params
    end

    before { request }

    context 'missing time frame id' do
      let(:params) do
        {
          population_id: target_population3.id,
          language_id: target_language2.id
        }
      end

      it_behaves_like 'correct response'

      it 'returns correct data' do
        expect(json_response['data'].map { |h| h['id'].to_i }).to match_array([test_types[2].id])
      end
    end

    context 'missing required parameters' do
      let(:params) { {} }

      it 'returns correct HTTP status code (Bad Request)' do
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
