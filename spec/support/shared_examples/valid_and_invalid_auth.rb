# frozen_string_literal: true

RSpec.shared_examples 'unauthorized user' do
  before { request }

  it { expect(response).to have_http_status(:unauthorized) }
end

RSpec.shared_examples 'authorized user' do
  before { request }

  it 'response contains generated uid token' do
    expect(response.headers.to_h).to include(
      'Uid' => user.email
    )
  end
end
