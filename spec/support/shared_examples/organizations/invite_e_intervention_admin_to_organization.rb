# frozen_string_literal: true

RSpec.shared_examples 'user who is not able to invite e-intervention admin to the organization' do
  it 'returns :forbidden status and not authorized message' do
    expect(V1::Organizations::InviteEInterventionAdmin).not_to receive(:call)
    request
    expect(response).to have_http_status(:forbidden)
    expect(json_response['message']).to eq('You are not authorized to access this page.')
  end
end
