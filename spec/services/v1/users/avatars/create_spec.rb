# frozen_string_literal: true

RSpec.describe V1::Users::Avatars::Create do
  subject { described_class.call(user, file) }

  let(:time) { Time.zone.local(2020, 2, 2, 12, 12) }
  let!(:user) { create(:user) }
  let!(:file) { FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true) }

  before do
    Timecop.freeze(time)
  end

  after do
    Timecop.return
  end

  context 'file is proper' do
    it 'attaches new avatar' do
      expect { subject }.to change { user.reload.avatar.attached? }.from(false).to(true)
    end
  end

  context 'file is null' do
    let(:file) { nil }

    it 'does not attach new avatar' do
      expect { subject }.not_to change { user.reload.avatar.attached? }
    end
  end
end
