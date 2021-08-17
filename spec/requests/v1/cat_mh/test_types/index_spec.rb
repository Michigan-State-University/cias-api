# frozen_string_literal: true

RSpec.describe 'GET /v1/cat_mh/test_types', type: :request do
  let_it_be(:user) { create(:user, :confirmed, :admin) }
  let_it_be(:headers) { user.create_new_auth_token }
  let_it_be(:languages) { CatMhLanguage.create!([{ language_id: 1, name: 'English' }, { language_id: 2, name: 'Spanish' }]) }
  let_it_be(:populations) { [CatMhPopulation.create!(name: 'General'), CatMhPopulation.create!(name: 'Perinatal')] }
  let_it_be(:time_frames) do
    CatMhTimeFrame.create!([{ timeframe_id: 1, description: 'Past hour', short_name: '1h' }, { timeframe_id: 2, description: 'Lifetime', short_name: 'life' }])
  end
  let_it_be(:test_types) do
    CatMhTestType.create!([
                            { short_name: 'mdd', name: 'Major depressive disorder', cat_mh_population: populations[0],
                              cat_mh_languages: languages, cat_mh_time_frames: time_frames },
                            { short_name: 'p-mdd', name: 'Major depressive disorder (Perinatal)',
                              cat_mh_population: populations[1], cat_mh_languages: languages, cat_mh_time_frames: time_frames }
                          ])
  end

  let(:time_frame_relationship_data) { json_response['data'].map { |h| h['relationships']['cat_mh_time_frames']['data'] } }
  let(:language_relationship_data) { json_response['data'].map { |h| h['relationships']['cat_mh_languages']['data'] } }
  let(:population_relationship_data) { json_response['data'].map { |h| h['relationships']['cat_mh_population']['data'] } }

  let(:request) do
    get v1_cat_mh_test_types_path, headers: headers
  end

  before { request }

  context 'returns proper data' do
    it 'returns proper data size' do
      expect(json_response['data'].size).to eq(test_types.size)
    end

    it 'returns proper data' do
      expect(json_response['data'].map { |h| h['id'].to_i }).to match_array(test_types.pluck(:id))
    end

    it 'returns proper HTTP Status code (OK)' do
      expect(response).to have_http_status(:ok)
    end

    context 'returns proper relationship data' do
      it 'returns correct language data' do
        # here we map each of the lists to a list of corresponding IDs and later check against the prepared languages
        language_ids = language_relationship_data.map { |langs| langs.map { |h| h['id'].to_i } }
        expect(language_ids).to all(match_array(languages.pluck(:id)))
      end

      it 'returns correct time frame data' do
        # same as with languages
        time_frame_ids = time_frame_relationship_data.map { |frames| frames.map { |h| h['id'].to_i } }
        expect(time_frame_ids).to all(match_array(time_frames.pluck(:id)))
      end

      it 'returns correct population data' do
        # test type can only have 1 population, so it easily maps to a 1-dimensional list
        expect(population_relationship_data.map { |h| h['id'].to_i }).to match_array(populations.pluck(:id))
      end
    end
  end

  context 'unauthorized user' do
    context 'users with different roles' do
      %i[participant researcher].each do |role|
        context "with role #{role}" do
          let(:user) { create(:user, :confirmed, role, ability_to_create_cat_mh: false) }
          let(:headers) { user.create_new_auth_token }
          let(:request) do
            get v1_cat_mh_test_types_path, headers: headers
          end

          it 'returns correct HTTP code (Forbidden)' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end

  context 'authorized user' do
    context 'CAT-MH permitted users' do
      %i[researcher e_intervention_admin].each do |role|
        context "user with role #{role}" do
          let(:user) { create(:user, :confirmed, role, ability_to_create_cat_mh: true) }
          let(:headers) { user.create_new_auth_token }
          let(:request) do
            get v1_cat_mh_test_types_path, headers: headers
          end

          it 'returns correct HTTP code (OK)' do
            expect(response).to have_http_status(:ok)
          end
        end
      end
    end
  end
end
