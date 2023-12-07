# frozen_string_literal: true

RSpec.shared_examples 'closed session' do
  let!(:intervention) { create(:intervention, user_id: user.id) }
  let!(:session) { create(:session, intervention: intervention, autoclose_enabled: true, autoclose_at: (DateTime.now - 2.days)) }

  before { request }

  it 'returns correct response code' do
    expect(response).to have_http_status(:bad_request)
  end

  it 'returns proper error message' do
    expect(json_response['message']).to include('You try to fill session after the time defined by researcher')
  end
end
