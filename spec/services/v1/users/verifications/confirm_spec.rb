# frozen_string_literal: true

RSpec.describe V1::Users::Verifications::Confirm do
  subject { described_class.call(verification_code, user.email) }

  let(:current_time) { Time.zone.local(2020, 2, 2, 12, 12) }
  let(:verification_code) { "verification_code_#{user.email}" }

  before do
    Timecop.freeze(current_time)
  end

  after do
    Timecop.return
  end

  context 'when user confirm the code before 30 minute' do
    let!(:user) { create(:user) }
    let!(:update_code) { user.user_verification_codes.last.update(confirmed: false) }

    it 'confirm verification code' do
      expect { subject }.to change { user.reload.user_verification_codes.last.confirmed }.from(false).to(true)
    end
  end

  context 'when user confirm the code after 30 minute' do
    let!(:user) { create(:user) }
    let!(:change_code_created_at) do
      user.user_verification_codes.last.update!(created_at: current_time - 1.hour)
    end

    it "don't confirm verification code" do
      expect { subject }.not_to change { user.reload.user_verification_codes.last }
    end
  end

  context 'when user confirm the logging with code of another user' do
    let(:verification_code) { "verification_code_#{user2.email}" }

    let!(:user) { create(:user) }
    let!(:user2) { create(:user) }

    it "don't confirm verification code" do
      expect { subject }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end

  describe 'E2E verification code bypass' do
    let(:e2e_code) { 'e2e_test_bypass_code' }
    let(:verification_code) { e2e_code }
    let!(:user) { create(:user) }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('E2E_VERIFICATION_CODE', nil).and_return(e2e_code)
      user.user_verification_codes.create!(code: e2e_code, confirmed: false, created_at: current_time - 2.hours)
    end

    context 'when in non-production environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
      end

      it 'confirms the E2E verification code even if expired' do
        expect { subject }.to change { user.reload.user_verification_codes.find_by(code: e2e_code).confirmed }.from(false).to(true)
      end

      it 'returns the verification code' do
        expect(subject).to eq(e2e_code)
      end
    end

    context 'when in production environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'does not confirm the expired E2E verification code' do
        expect { subject }.not_to change { user.reload.user_verification_codes.find_by(code: e2e_code).confirmed }
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end
end
