# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Auth::WebAppRedirectUrlCheck do
  describe '.allowed?' do
    let(:web_url) { 'https://web.example.test' }

    before { stub_const('ENV', ENV.to_hash.merge('WEB_URL' => web_url)) }

    {
      'https://web.example.test/set-new-password' => true,
      'https://web.example.test' => true,
      'https://web.example.test:443/login?lang=en#top' => true,
      'https://WEB.Example.TEST/login' => true,
      'https://web.example.test@other.example.test/set-new-password' => false,
      'https://someone@web.example.test/set-new-password' => false,
      'https://web.example.test.other.example.test/set-new-password' => false,
      'https://web.example.test:8443/set-new-password' => false,
      'http://web.example.test/set-new-password' => false,
      'http://web.example.test:443/set-new-password' => false,
      '/set-new-password' => false,
      'not a url' => false,
      '' => false,
      nil => false,
      { 'url' => 'https://web.example.test' } => false
    }.each do |url, expected|
      it "returns #{expected} for #{url.inspect}" do
        expect(described_class.allowed?(url)).to be(expected)
      end
    end

    context 'when WEB_URL has a non-default port' do
      let(:web_url) { 'http://localhost:4200' }

      it 'allows the same port' do
        expect(described_class.allowed?('http://localhost:4200/login')).to be(true)
      end

      it 'rejects the default port' do
        expect(described_class.allowed?('http://localhost/login')).to be(false)
      end
    end

    context 'when WEB_URL is not set' do
      before { stub_const('ENV', ENV.to_hash.except('WEB_URL')) }

      it 'rejects every URL' do
        expect(described_class.allowed?('https://web.example.test/set-new-password')).to be(false)
      end
    end
  end
end
