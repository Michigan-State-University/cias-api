# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::TestRuns::LinkToken do
  let(:intervention_id) { SecureRandom.uuid }
  let(:minted_by_id) { SecureRandom.uuid }
  let(:minted) { described_class.mint(intervention_id, minted_by_id) }

  describe '.mint' do
    it 'returns a token, its expiry and its nonce' do
      expect(minted.token).to be_present
      expect(minted.nonce).to be_present
      expect(minted.expires_at).to be_within(5.seconds).of(described_class.ttl.from_now)
    end

    it 'produces a URL-safe token' do
      expect(minted.token).not_to match(%r{[+/=]})
    end

    it 'never repeats a nonce' do
      expect(described_class.mint(intervention_id, minted_by_id).nonce).not_to eq(minted.nonce)
    end
  end

  describe '.verify' do
    it 'returns the payload for a token minted for the same intervention' do
      expect(described_class.verify(minted.token, intervention_id)).to eq(
        'intervention_id' => intervention_id, 'minted_by_id' => minted_by_id, 'nonce' => minted.nonce
      )
    end

    it 'carries the minting user so the marker can be attributed' do
      expect(described_class.verify(minted.token, intervention_id)['minted_by_id']).to eq(minted_by_id)
    end

    it 'rejects a token minted for a different intervention' do
      expect(described_class.verify(minted.token, SecureRandom.uuid)).to be_nil
    end

    it 'rejects a tampered signature' do
      tampered = minted.token.sub(/.\z/) { |char| char == 'a' ? 'b' : 'a' }

      expect(described_class.verify(tampered, intervention_id)).to be_nil
    end

    it 'rejects a tampered payload' do
      payload, signature = minted.token.split('--')
      forged = Base64.urlsafe_encode64(
        Base64.urlsafe_decode64(payload).sub(intervention_id, SecureRandom.uuid), padding: false
      )

      expect(described_class.verify("#{forged}--#{signature}", intervention_id)).to be_nil
    end

    it 'rejects an expired token' do
      token = minted.token

      Timecop.travel(described_class.ttl.from_now + 1.minute) do
        expect(described_class.verify(token, intervention_id)).to be_nil
      end
    end

    # `PURPOSE` doubles as the key-derivation salt, so a token from any other verifier in the app
    # dies on the signature long before the purpose is looked at. That is worth pinning, but it is
    # *key* separation, not purpose separation — the example below covers the purpose itself.
    it 'rejects a token signed with a different derived key' do
      foreign_key = Rails.application.message_verifier(:something_else).generate(
        { 'intervention_id' => intervention_id, 'nonce' => SecureRandom.uuid }
      )

      expect(described_class.verify(foreign_key, intervention_id)).to be_nil
    end

    it 'rejects a token minted with this class own key but another purpose' do
      wrong_purpose = described_class.send(:verifier).generate(
        { 'intervention_id' => intervention_id, 'minted_by_id' => minted_by_id, 'nonce' => SecureRandom.uuid },
        purpose: 'cias/some_other_purpose',
        expires_at: described_class.ttl.from_now
      )

      expect(described_class.verify(wrong_purpose, intervention_id)).to be_nil
    end

    it 'rejects garbage and blanks without raising' do
      expect(described_class.verify('not-a-token', intervention_id)).to be_nil
      expect(described_class.verify('', intervention_id)).to be_nil
      expect(described_class.verify(nil, intervention_id)).to be_nil
      expect(described_class.verify(minted.token, nil)).to be_nil
    end

    # D8, revised: the per-token ceiling and the counter behind it are gone, so verification is
    # stateless and a link marks every fill that presents it inside the TTL. A ceiling only moved
    # the silent-failure cliff — the fill past it became a permanent, un-purgeable real
    # participant. This fails the moment anything here starts counting again.
    it 'stays valid however many times it is presented' do
      expect(Array.new(10) { described_class.verify(minted.token, intervention_id) }).to all(be_present)
    end
  end

  # `verify` answers one yes/no and collapses every rejection into `nil`. `inspect_token` is the
  # same three checks with the reason kept, because the landing-time gate has to say "your link
  # expired, copy a fresh one" rather than a shrug.
  describe '.inspect_token' do
    it 'reports a live token as valid and hands back its payload' do
      inspection = described_class.inspect_token(minted.token)

      expect(inspection).to have_attributes(status: :valid, intervention_id: intervention_id)
      expect(inspection).to be_valid
      expect(inspection.payload['nonce']).to eq(minted.nonce)
    end

    it 'tells an expired token apart from a broken one' do
      token = minted.token

      Timecop.travel(described_class.ttl.from_now + 1.minute) do
        expect(described_class.inspect_token(token)).to have_attributes(status: :expired, payload: nil)
      end
    end

    it 'takes no opinion on which intervention the token names' do
      expect(described_class.inspect_token(minted.token).intervention_id).to eq(intervention_id)
    end

    it 'leaves the token exactly as usable as it found it' do
      3.times { described_class.inspect_token(minted.token) }

      expect(described_class.verify(minted.token, intervention_id)).to be_present
    end

    shared_examples 'an unrecognised token' do
      it { expect(described_class.inspect_token(token)).to have_attributes(status: :invalid, payload: nil) }
    end

    context 'when the signature was tampered with' do
      let(:token) { minted.token.sub(/.\z/) { |char| char == 'a' ? 'b' : 'a' } }

      it_behaves_like 'an unrecognised token'
    end

    context 'when the payload was tampered with' do
      let(:token) do
        payload, signature = minted.token.split('--')
        forged = Base64.urlsafe_encode64(
          Base64.urlsafe_decode64(payload).sub(intervention_id, SecureRandom.uuid), padding: false
        )
        "#{forged}--#{signature}"
      end

      it_behaves_like 'an unrecognised token'
    end

    context 'when the token comes from another verifier' do
      let(:token) { Rails.application.message_verifier(:something_else).generate({ 'nonce' => SecureRandom.uuid }) }

      it_behaves_like 'an unrecognised token'
    end

    context 'when it is not a token at all' do
      let(:token) { 'not-a-token' }

      it_behaves_like 'an unrecognised token'
    end

    context 'when it is blank' do
      let(:token) { '' }

      it_behaves_like 'an unrecognised token'
    end

    context 'when it is nil' do
      let(:token) { nil }

      it_behaves_like 'an unrecognised token'
    end
  end

  describe '.ttl' do
    subject(:ttl) { described_class.ttl }

    let(:env_value) { nil }

    around do |example|
      original = ENV.fetch('TEST_LINK_TOKEN_TTL_MINUTES', nil)
      ENV['TEST_LINK_TOKEN_TTL_MINUTES'] = env_value
      example.run
    ensure
      ENV['TEST_LINK_TOKEN_TTL_MINUTES'] = original
    end

    context 'when the env var is unset' do
      it { expect(ttl).to eq(described_class::DEFAULT_TTL_MINUTES.minutes) }
    end

    context 'when the env var holds a positive number' do
      let(:env_value) { '30' }

      it { expect(ttl).to eq(30.minutes) }
    end

    # A blank or junk value used to coerce to `0.minutes`, which minted tokens that were already
    # expired: the feature died silently and every fill quietly failed open and unmarked.
    context 'when the env var is blank' do
      let(:env_value) { '' }

      it { expect(ttl).to eq(described_class::DEFAULT_TTL_MINUTES.minutes) }
    end

    context 'when the env var is not a number' do
      let(:env_value) { 'fifteen' }

      it { expect(ttl).to eq(described_class::DEFAULT_TTL_MINUTES.minutes) }
    end

    context 'when the env var is zero or negative' do
      it 'falls back to the default for zero' do
        ENV['TEST_LINK_TOKEN_TTL_MINUTES'] = '0'

        expect(described_class.ttl).to eq(described_class::DEFAULT_TTL_MINUTES.minutes)
      end

      it 'falls back to the default for a negative value' do
        ENV['TEST_LINK_TOKEN_TTL_MINUTES'] = '-5'

        expect(described_class.ttl).to eq(described_class::DEFAULT_TTL_MINUTES.minutes)
      end
    end
  end
end
