# frozen_string_literal: true

RSpec.describe V1::Users::Verifications::Create do
  subject { described_class.call(user, verification_code_from_headers) }

  let(:time) { Time.zone.local(2020, 2, 2, 12, 12) }
  let!(:user) { create(:user) }
  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

  before do
    Timecop.freeze(time)
    allow(message_delivery).to receive(:deliver_later)
    allow(SecureRandom).to receive(:base64).and_return('456')
    ActiveJob::Base.queue_adapter = :test
  end

  after do
    Timecop.return
  end

  context 'when first login' do
    let(:verification_code_from_headers) { nil }
    let!(:remove_verification_code) do
      user.user_verification_codes.last.delete
    end

    it 'generate new code and send email' do
      expect(UserMailer).to receive(:send_verification_login_code).with(verification_code: '456', email: user.email).and_return(message_delivery)
      subject
      user_verification_codes = user.reload.user_verification_codes
      expect(user_verification_codes.count).to eq 1
      expect(user_verification_codes.last.code).to eq '456'
    end
  end

  context 'when log in on other browser than previous login' do
    let(:verification_code_from_headers) { nil }

    it 'generate new code and send email' do
      expect(UserMailer).to receive(:send_verification_login_code).with(
        verification_code: '456', email: user.email
      ).and_return(message_delivery)
      subject
      user_verification_codes = user.reload.user_verification_codes
      expect(user_verification_codes.count).to eq 2
      expect(user_verification_codes.exists?(code: '456')).to eq true
    end
  end

  context 'when verification_code is expired' do
    let(:verification_code_from_headers) { "verification_code_#{user.email}" }
    let!(:change_code_created_at) do
      user.user_verification_codes.last.update!(created_at: time - 33.days)
    end

    it 'generate new code and send email' do
      expect(UserMailer).to receive(:send_verification_login_code).with(
        verification_code: '456', email: user.email
      ).and_return(message_delivery)
      subject
      user_verification_codes = user.reload.user_verification_codes
      expect(user_verification_codes.count).to eq 1
      expect(user_verification_codes.last.code).to eq '456'
    end
  end

  context 'when verification_code is present and is valid' do
    let(:verification_code_from_headers) { "verification_code_#{user.email}" }

    it "don't send email and generate new code" do
      expect(UserMailer).not_to receive(:send_verification_login_code)
      subject
      user_verification_codes = user.reload.user_verification_codes
      expect(user_verification_codes.count).to eq 1
      expect(user_verification_codes.last.code).to eq "verification_code_#{user.email}"
    end
  end

  context 'when exists verification code of another user in headers' do
    let!(:another_user) { create(:user) }
    let(:verification_code_from_headers) { "verification_code_#{another_user.email}" }
    let!(:user) { create(:user) }

    it 'generate new code and send email' do
      subject

      user_verification_codes = user.reload.user_verification_codes
      expect(user_verification_codes.count).to eq 2
      expect(user_verification_codes.exists?(code: '456')).to eq true
    end
  end
end
