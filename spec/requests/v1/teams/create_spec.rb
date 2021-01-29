# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/teams', type: :request do
  let(:request) { post v1_teams_path, params: params, headers: headers }
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:params) do
    {
      team: {
        name: 'Best Team'
      }
    }
  end

  context 'when params' do
    context 'valid' do
      it 'returns :created status' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates new team with proper name' do
        expect { request }.to change(Team, :count).by(1)
        expect(Team.last).to have_attributes(
          name: 'Best Team'
        )
      end
    end

    context 'invalid' do
      context 'params' do
        let(:params) { { team: {} } }

        it 'returns :bad_request status' do
          request
          expect(response).to have_http_status(:bad_request)
        end

        it 'does not create a new team' do
          expect { request }.not_to change(Team, :count)
        end
      end
    end
  end
end
