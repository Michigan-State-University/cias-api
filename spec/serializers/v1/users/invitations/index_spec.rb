# frozen_string_literal: true

require 'rails_helper'

describe V1::Users::Invitations::Index, type: :serializer do
  subject { described_class.new(users: [user_1, user_2]) }

  let(:user_1) { create(:user, email: 'test@example.com') }
  let(:user_2) { create(:user, email: 'other@example.com') }

  describe '#to_json' do
    it 'returns serialized hash' do
      result = subject.to_json

      expect(result[:invitations].size).to eq 2
      expect(result[:invitations][0][:email]).to eq 'test@example.com'
    end
  end
end
