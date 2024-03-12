# frozen_string_literal: true

RSpec.shared_examples 'without health clinic' do
  subject { user.valid? }

  it 'does not have health clinic' do
    expect(user.organizable).to be_nil
    subject
  end
end

RSpec.shared_examples 'with health clinic' do
  subject { user.valid? }

  let(:health_clinic) { create(:health_clinic) }

  before do
    user.organizable = health_clinic
    UserHealthClinic.create!(user: user, health_clinic: health_clinic)
  end

  it 'has health clinic' do
    expect(user.organizable).to eql(health_clinic)
    expect(user.user_health_clinics.size).to be(1)
    subject
  end
end
