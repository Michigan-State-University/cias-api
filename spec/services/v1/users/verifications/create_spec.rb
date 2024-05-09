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

  shared_examples 'generating codes' do
    let_it_be(:code) { '456' }

    it 'generate new code and send email' do
      allow(UserMailer).to receive(:send_verification_login_code).with(verification_code: code,
                                                                       email: user.email).and_return(message_delivery)
      subject
      user_verification_codes = user.reload.user_verification_codes
      expect(user_verification_codes.count).to eq number_of_codes
      expect(user_verification_codes.exists?(code: code)).to be true if exist456 == true
      expect(user_verification_codes.last.code).to eq last_code if last_code
    end
  end

  context 'when first login' do
    let(:verification_code_from_headers) { nil }
    let!(:remove_verification_code) do
      user.user_verification_codes.last.delete
    end

    it_behaves_like 'generating codes' do
      let(:number_of_codes) { 1 }
      let(:last_code) { '456' }
      let(:exist456) { true }
    end
  end

  context 'when log in on other browser than previous login' do
    let(:verification_code_from_headers) { nil }

    it_behaves_like 'generating codes' do
      let(:number_of_codes) { 2 }
      let(:last_code) { nil }
      let(:exist456) { true }
    end
  end

  context 'when verification_code is expired' do
    let(:verification_code_from_headers) { "verification_code_#{user.email}" }
    let!(:change_code_created_at) do
      user.user_verification_codes.last.update!(created_at: time - 33.days)
    end

    it_behaves_like 'generating codes' do
      let(:number_of_codes) { 1 }
      let(:last_code) { '456' }
      let(:exist456) { true }
    end
  end

  context 'when verification_code is present and is valid' do
    let(:verification_code_from_headers) { "verification_code_#{user.email}" }

    it_behaves_like 'generating codes' do
      let(:number_of_codes) { 1 }
      let(:last_code) { "verification_code_#{user.email}" }
      let(:exist456) { false }
    end
  end

  context 'when exists verification code of another user in headers' do
    let!(:another_user) { create(:user) }
    let(:verification_code_from_headers) { "verification_code_#{another_user.email}" }
    let!(:user) { create(:user) }

    it_behaves_like 'generating codes' do
      let(:number_of_codes) { 2 }
      let(:last_code) { nil }
      let(:exist456) { true }
    end
  end
end
