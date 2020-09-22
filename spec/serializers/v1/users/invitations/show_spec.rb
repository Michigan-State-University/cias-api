# frozen_string_literal: true

require 'rails_helper'

describe V1::Users::Invitations::Show, type: :serializer do
  subject { described_class.new(user: user) }

  let(:user) { create(:user, email: 'test@example.com') }

  describe '#to_json' do
    it 'returns serialized hash' do
      result = subject.to_json

      expect(result[:email]).to eq 'test@example.com'
    end
  end
end
