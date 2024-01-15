# frozen_string_literal: true

RSpec.shared_examples 'paused intervention' do
  let!(:intervention) { create(:intervention, :paused, user_id: user.id) }

  before { request }

  it 'returns correct response code' do
    expect(response).to have_http_status(:bad_request)
  end

  it 'returns proper error message' do
    expect(json_response['message']).to include('This study is temporarily unavailable. Please check with the research team or clinic to find out when it will resume, or try back later')
  end
end
