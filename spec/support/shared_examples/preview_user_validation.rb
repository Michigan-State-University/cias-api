# frozen_string_literal: true

RSpec.shared_examples 'preview user' do
  before { request }

  it 'returns proper error message' do
    expect(json_response['message']).to eq('Couldn\'t find Session without an ID')
  end
end
