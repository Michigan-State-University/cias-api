# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/preview_session_users', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:params) do
    {
      session_id: session.id
    }
  end
  let(:preview_session_user) { User.limit_to_roles('preview_session').last }
  let(:request) { post v1_preview_session_users_path, params: params, headers: headers }

  it 'set proper response headers and return created status' do
    request

    expect(response).to have_http_status(:ok)
    expect(json_response['Client']).to be_present
    expect(json_response['Access-Token']).to be_present
    expect(json_response['Uid']).to eq preview_session_user.uid
    expect(preview_session_user.preview_session_id).to eq session.id
  end

  context 'CAT-MH preview' do
    let(:session) { create(:cat_mh_session, intervention: intervention) }
    let(:params) { { session_id: session.id } }

    before { request }

    it 'returns correct HTTP status code (Method Not Allowed)' do
      expect(response).to have_http_status(:method_not_allowed)
    end

    it 'returns proper message' do
      expect(json_response['message']).to eq I18n.t('users.preview.cat_mh')
    end
  end
end
