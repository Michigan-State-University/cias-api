# frozen_string_literal: true

RSpec.shared_examples 'user who is not able to invite health_system admin to the health_system' do
  it 'returns :forbidden status and not authorized message' do
    expect(V1::HealthSystems::InviteHealthSystemAdmin).not_to receive(:call)
    request
    expect(response).to have_http_status(:forbidden)
    expect(json_response['message']).to eq('You are not authorized to access this page.')
  end
end
