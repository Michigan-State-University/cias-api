# frozen_string_literal: true

RSpec.describe V1::Users::Invitations::Create do
  subject { described_class.call(email) }

  let(:time) { Time.zone.local(2020, 2, 2, 12, 12) }
  let!(:user) { create(:user) }
  let!(:email) { user.email }

  before do
    Timecop.freeze(time)
  end

  after do
    Timecop.return
  end

  context 'email is valid' do
    context 'user exists in the system' do
      it 'does not create new user' do
        expect { subject }.not_to change(User, :count)
      end
    end

    context 'user does not exist in the system' do
      let(:email) { 'example_user@example.com' }

      it 'creates new user' do
        expect { subject }.to change(User, :count).by(1)
        expect(User.exists?(email: email)).to be true
        expect(User.find_by(email: email).confirmed?).to be false
      end
    end
  end

  context 'email is invalid' do
    let(:email) { nil }

    it 'does not create new user' do
      expect { subject }.not_to change(User, :count)
    end
  end
end
