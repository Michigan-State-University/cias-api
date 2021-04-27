# frozen_string_literal: true

RSpec.describe V1::Users::Verifications::Confirm do
  subject { described_class.call(verification_code) }

  let(:current_time) { Time.zone.local(2020, 2, 2, 12, 12) }
  let(:verification_code) { '1234' }

  before do
    Timecop.freeze(current_time)
  end

  after do
    Timecop.return
  end

  context 'when user confirm the code before 30 minute' do
    let!(:user) { create(:user, verification_code: verification_code, confirmed_verification: false) }

    it 'confirm verification code' do
      expect { subject }.to change { user.reload.confirmed_verification }.from(false).to(true)
    end
  end

  context 'when user confirm the code after 30 minute' do
    let(:verification_code_created_at) { current_time - 1.hour }
    let!(:user) do
      create(:user, verification_code: verification_code, confirmed_verification: false,
                    verification_code_created_at: verification_code_created_at)
    end

    it "don't confirm verification code" do
      expect { subject }.not_to change { user.reload.confirmed_verification }
    end
  end
end
