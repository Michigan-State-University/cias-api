# frozen_string_literal: true

RSpec.describe V1::Users::Verifications::Create do
  subject { described_class.call(user, verification_code_from_headers) }

  let(:time) { Time.zone.local(2020, 2, 2, 12, 12) }
  let(:user) do
    create(:user, verification_code: verification_code, verification_code_created_at: verification_code_created_at)
  end
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
    let(:verification_code) { nil }
    let(:verification_code_created_at) { nil }

    it 'generate new code and send email' do
      expect(UserMailer).to receive(:send_verification_login_code).with(verification_code: '456', email: user.email).and_return(message_delivery)
      subject
      updated_user = user.reload
      expect(updated_user.verification_code).to eq '456'
      expect(updated_user.verification_code_created_at).to eq time
    end
  end

  context 'when log in on other browser than previous login' do
    let(:verification_code_from_headers) { nil }
    let(:verification_code) { '123' }
    let!(:verification_code_created_at) { time }

    it 'generate new code and send email' do
      expect(UserMailer).to receive(:send_verification_login_code).with(verification_code: '456', email: user.email).and_return(message_delivery)
      subject
      updated_user = user.reload
      expect(updated_user.verification_code).to eq '456'
      expect(updated_user.verification_code_created_at).to eq time
    end
  end

  context 'when verification_code is expired' do
    let(:verification_code_from_headers) { '123' }
    let(:verification_code) { '123' }
    let(:verification_code_created_at) { Time.zone.local(2019, 2, 2, 12, 12) }

    it 'generate new code and send email' do
      expect(UserMailer).to receive(:send_verification_login_code).with(verification_code: '456', email: user.email).and_return(message_delivery)
      subject
      updated_user = user.reload
      expect(updated_user.verification_code).to eq '456'
      expect(updated_user.verification_code_created_at).to eq time
    end
  end

  context 'when verification_code is present and is valid' do
    let(:verification_code_from_headers) { '123' }
    let(:verification_code) { '123' }
    let!(:verification_code_created_at) { time }

    it "don't send email and generate new code" do
      expect(UserMailer).not_to receive(:send_verification_login_code)
      subject
      updated_user = user.reload
      expect(updated_user.verification_code).to eq '123'
    end
  end

  context 'when exists verification code of another user in headers' do
    let(:verification_code_from_headers) { '123' }
    let!(:verification_code_created_at) { time }
    let!(:another_user) do
      create(:user, verification_code: verification_code_from_headers,
                    confirmed_verification: true, verification_code_created_at: verification_code_created_at)
    end
    let!(:user) do
      create(:user, verification_code: nil, verification_code_created_at: nil, confirmed_verification: false)
    end

    it 'generate new code and send email' do
      expect { subject }.to change(user, :verification_code).from(nil).to('456')
    end
  end
end
