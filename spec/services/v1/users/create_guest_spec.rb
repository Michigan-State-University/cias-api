# frozen_string_literal: true

RSpec.describe V1::Users::CreateGuest do
  subject { described_class.call }

  let(:guest_user) { User.last }

  it 'creates guest user' do
    expect { subject }.to change(User, :count).by(1)
  end

  it 'new user has proper attributes' do
    subject
    expect(guest_user.roles).to eql %w[guest]
    expect(guest_user.email).to include '@guest.true'
    expect(guest_user.valid?).to be true
    expect(guest_user.confirmed?).to be true
  end
end
