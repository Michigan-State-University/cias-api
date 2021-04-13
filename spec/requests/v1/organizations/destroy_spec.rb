# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/organizations/:id', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:team_admin) { create(:user, :confirmed, :team_admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:guest) { create(:user, :confirmed, :guest) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, name: 'Michigan Public Health') }

  let(:headers) { user.create_new_auth_token }
  let(:request) { delete v1_organization_path(organization.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_organization_path(organization.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      before { request }

      it 'returns correct status' do
        expect(response).to have_http_status(:no_content)
      end

      it 'organization is deleted' do
        expect(Organization.find_by(id: organization.id)).to eq(nil)
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'

      context 'when organization id is invalid' do
        before do
          delete v1_organization_path('wrong_id'), headers: headers
        end

        it 'error message is expected' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end
    end

    context 'when user is team admin' do
      let(:headers) { team_admin.create_new_auth_token }

      it_behaves_like 'unpermitted user'
    end

    context 'when user is researcher' do
      let(:headers) { researcher.create_new_auth_token }

      it_behaves_like 'unpermitted user'
    end

    context 'when user is participant' do
      let(:headers) { participant.create_new_auth_token }

      it_behaves_like 'unpermitted user'
    end

    context 'when user is guest' do
      let(:headers) { guest.create_new_auth_token }

      it_behaves_like 'unpermitted user'
    end

    context 'when user is preview user' do
      let(:headers) { preview_user.create_new_auth_token }

      before { request }

      it 'returns proper error message' do
        expect(json_response['message']).to eq('Couldn\'t find Session without an ID')
      end
    end
  end
end
