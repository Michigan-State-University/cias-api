# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'filter_parameters', type: :model do
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }
  let(:slug) { 'ciastddcanaryslug' }
  let(:url) { 'https://example.test/canary-target' }
  let(:phone) { '+12015550123' }
  let(:masked) { ActiveSupport::ParameterFilter::FILTERED }

  describe 'Rails.application.config.filter_parameters' do
    %w[slug token url phone].each do |key|
      it "masks a top-level #{key}" do
        expect(filter.filter({ key => slug, 'status' => 'visible' })).to eq(key => masked, 'status' => 'visible')
      end

      it "masks a #{key} given as a symbol key" do
        expect(filter.filter({ key.to_sym => slug })).to eq(key.to_sym => masked)
      end
    end

    it 'masks the canonical values nested under sms_link' do
      filtered = filter.filter({ 'sms_link' => { 'slug' => slug, 'url' => url, 'variable' => 'visible' } })
      expect(filtered['sms_link']).to eq('slug' => masked, 'url' => masked, 'variable' => 'visible')
    end

    it 'masks the canonical values inside arrays of hashes' do
      filtered = filter.filter({ 'links' => [{ 'url' => url, 'variable' => 'visible' }] })
      expect(filtered['links']).to eq([{ 'url' => masked, 'variable' => 'visible' }])
    end

    it 'masks a phone inside a deeply nested payload' do
      filtered = filter.filter({ 'predefined_user' => { 'profile' => { 'phone' => phone } } })
      expect(filtered.to_s).not_to include(phone)
    end

    it 'does not leak any canonical value in a combined payload' do
      filtered = filter.filter({ 'slug' => slug, 'token' => slug, 'sms_link' => { 'url' => url }, 'phone' => phone })
      expect(filtered.to_s).not_to include(slug, url, phone)
    end

    it 'keeps masking the parameters that were already filtered' do
      expect(filter.filter({ 'password' => 'x', 'email' => 'x', 'number' => 'x', 'body' => 'x' }).values).to all(eq(masked))
    end
  end

  describe "Sentry's before_send" do
    let(:event) { Sentry::Event.new(configuration: Sentry.configuration) }
    let(:filtered) { Sentry.configuration.before_send.call(event, {}) }

    before do
      event.extra = { slug: slug, token: slug, sms_link: { url: url }, phone: phone, status: 'visible' }
    end

    it 'masks slug, token, url and phone in the event payload' do
      expect(filtered[:extra]).to eq(slug: masked, token: masked, sms_link: { url: masked }, phone: masked, status: 'visible')
    end

    it 'leaves no canonical value anywhere in the serialised event' do
      expect(filtered.to_s).not_to include(slug, url, phone)
    end
  end
end
