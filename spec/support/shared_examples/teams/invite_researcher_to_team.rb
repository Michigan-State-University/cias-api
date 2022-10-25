# frozen_string_literal: true

RSpec.shared_examples 'user who can invite researcher to the team' do
  it 'service InviteResearcher is called' do
    expect(V1::Teams::Invite).to receive(:call).with(team, params[:email], params[:roles])
    request
    expect(response).to have_http_status(:created)
  end
end

RSpec.shared_examples 'user who is not able to invite researcher to the team' do
  it 'returns :forbidden status and not authorized message' do
    expect(V1::Teams::Invite).not_to receive(:call)
    request
    expect(response).to have_http_status(:forbidden)
    expect(json_response['message']).to eq('You are not authorized to access this page.')
  end
end
