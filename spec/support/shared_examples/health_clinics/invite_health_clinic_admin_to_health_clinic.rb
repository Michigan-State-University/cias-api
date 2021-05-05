# frozen_string_literal: true

RSpec.shared_examples 'user who is not able to invite health_clinic admin to the health_clinic' do
  it 'returns :forbidden status and not authorized message' do
    expect(V1::HealthClinics::InviteHealthClinicAdmin).not_to receive(:call)
    request
    expect(response).to have_http_status(:forbidden)
    expect(json_response['message']).to eq('You are not authorized to access this page.')
  end
end
