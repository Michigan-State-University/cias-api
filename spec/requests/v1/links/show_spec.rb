# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/s/:slug', type: :request do
  let!(:link) { create(:link, slug: 'example') }
  let(:request) { get v1_short_path(slug: link.slug) }

  it 'redirects to the link URL when given a valid slug' do
    request
    expect(response).to redirect_to(link.url)
  end

  context 'when slug is invalid' do
    let(:request) { get v1_short_path(slug: 'invalid_slug') }

    it do
      request
      expect(response).to have_http_status(:not_found)
    end
  end
end
