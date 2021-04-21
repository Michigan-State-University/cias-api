# frozen_string_literal: true

RSpec.shared_examples 'user who is able to invite organization admin to the organization' do
  it 'service InviteOrganizationAdmin is called' do
    expect(V1::Organizations::InviteOrganizationAdmin).to receive(:call).with(organization, params[:email])
    request
    expect(response).to have_http_status(:created)
  end
end

RSpec.shared_examples 'user who is not able to invite organization admin to the organization' do
  it 'returns :not_found status and not authorized message' do
    expect(V1::Organizations::InviteOrganizationAdmin).not_to receive(:call)
    request
    expect(response).to have_http_status(:forbidden)
    expect(json_response['message']).to eq('You are not authorized to access this page.')
  end
end

RSpec.shared_examples 'user who is not able to invite organization admin to other organization' do
  it 'returns :not_found status and not authorized message' do
    expect(V1::Organizations::InviteOrganizationAdmin).not_to receive(:call)
    request
    expect(response).to have_http_status(:not_found)
    expect(json_response['message']).to include('Couldn\'t find Organization with \'id\'=')
  end
end
