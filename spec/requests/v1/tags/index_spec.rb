# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/tags', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:request) { get v1_tags_path, headers: headers, params: params }
  let(:params) { {} }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { get v1_tags_path }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is authenticated' do
    context 'with tags in DB' do
      let!(:tag1) { create(:tag, name: 'Health') }
      let!(:tag2) { create(:tag, name: 'Mental Health') }
      let!(:tag3) { create(:tag, name: 'Wellness') }
      let!(:tag4) { create(:tag, name: 'Nutrition') }
      let!(:tag5) { create(:tag, name: 'Exercise') }

      before { request }

      context 'without any parameters' do
        it 'returns success status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns all tags' do
          expect(json_response['data'].size).to eq(5)
        end

        it 'returns correct tags_size' do
          expect(json_response['tags_size']).to eq(5)
        end

        it 'returns proper tag structure' do
          expect(json_response['data']).to all(
            include(
              'id' => be_a(String),
              'type' => 'tag',
              'attributes' => include(
                'name' => be_a(String)
              )
            )
          )
        end

        it 'includes all created tags' do
          tag_names = json_response['data'].map { |tag| tag['attributes']['name'] }
          expect(tag_names).to contain_exactly('Health', 'Mental Health', 'Wellness', 'Nutrition', 'Exercise')
        end
      end

      context 'with search parameter' do
        let(:params) { { search: 'health' } }

        it 'returns success status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns filtered tags' do
          expect(json_response['data'].size).to eq(2)
        end

        it 'returns tags matching the search term' do
          tag_names = json_response['data'].map { |tag| tag['attributes']['name'] }
          expect(tag_names).to contain_exactly('Health', 'Mental Health')
        end

        it 'returns correct tags_size for filtered results' do
          expect(json_response['tags_size']).to eq(2)
        end

        context 'with case-insensitive search' do
          let(:params) { { search: 'HEALTH' } }

          it 'returns matching tags regardless of case' do
            expect(json_response['data'].size).to eq(2)
            tag_names = json_response['data'].map { |tag| tag['attributes']['name'] }
            expect(tag_names).to contain_exactly('Health', 'Mental Health')
          end
        end

        context 'with partial match search' do
          let(:params) { { search: 'ell' } }

          it 'returns tags with partial matches' do
            expect(json_response['data'].size).to eq(1)
            expect(json_response['data'].first['attributes']['name']).to eq('Wellness')
          end
        end

        context 'with no matching tags' do
          let(:params) { { search: 'nonexistent' } }

          it 'returns empty data array' do
            expect(json_response['data']).to be_empty
          end

          it 'returns zero tags_size' do
            expect(json_response['tags_size']).to eq(0)
          end
        end
      end

      context 'with pagination parameters' do
        context 'with start_index and end_index' do
          let(:params) { { start_index: 0, end_index: 2 } }

          it 'returns success status' do
            expect(response).to have_http_status(:ok)
          end

          it 'returns paginated results' do
            expect(json_response['data'].size).to eq(3)
          end

          it 'returns correct total tags_size' do
            expect(json_response['tags_size']).to eq(5)
          end
        end

        context 'with out of range indices' do
          let(:params) { { start_index: 10, end_index: 20 } }

          it 'returns nil or empty data' do
            expect(json_response['data']).to be_nil.or be_empty
          end

          it 'returns correct total tags_size' do
            expect(json_response['tags_size']).to eq(5)
          end
        end
      end

      context 'with combined search and pagination' do
        let(:params) { { search: 'health', start_index: 0, end_index: 0 } }

        it 'returns success status' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns first paginated result of filtered tags' do
          expect(json_response['data'].size).to eq(1)
        end

        it 'returns correct tags_size for filtered results' do
          expect(json_response['tags_size']).to eq(2)
        end
      end
    end

    context 'when no tags exist' do
      before { request }

      it 'returns success status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns empty data array' do
        expect(json_response['data']).to be_empty
      end

      it 'returns zero tags_size' do
        expect(json_response['tags_size']).to eq(0)
      end
    end
  end
end
