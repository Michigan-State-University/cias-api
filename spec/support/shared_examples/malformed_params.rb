# frozen_string_literal: true

RSpec.shared_examples 'rejects malformed params' do |unchanged|
  it 'returns :bad_request with a message and changes nothing' do
    expect { request }.not_to(change { instance_exec(&unchanged) })
    expect(response).to have_http_status(:bad_request)
    expect(json_response).to include('message')
  end
end
