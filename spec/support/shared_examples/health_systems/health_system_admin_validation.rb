# frozen_string_literal: true

RSpec.shared_examples 'without health system' do
  subject { user.valid? }

  it 'does not have health system' do
    expect(user.organizable).to be_nil
    subject
  end
end

RSpec.shared_examples 'with health system' do
  subject { user.valid? }

  let(:health_system) { create(:health_system) }

  before do
    user.organizable = health_system
  end

  it 'has health system' do
    expect(user.organizable).to eql(health_system)
    subject
  end
end
