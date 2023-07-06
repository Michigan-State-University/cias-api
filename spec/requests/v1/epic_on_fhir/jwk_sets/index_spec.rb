# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/jwk-set', type: :request do
  before do
    get v1_jwk_set_path
  end

  it 'expect correct main key' do
    expect(json_response.keys).to match_array('keys')
  end

  it 'has correct keys' do
    expect(json_response['keys'].first.keys).to match_array(%w[kty n e kid alg])
  end
end
