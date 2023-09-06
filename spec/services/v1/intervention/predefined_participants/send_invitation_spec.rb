# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::SendInvitation do
  let(:subject) { described_class.call(user) }
  let!(:intervention) { create(:intervention, :with_predefined_participants) }
  let(:user) { intervention.predefined_users.first }

  it 'when user is without phone' do
    expect { subject }.not_to change(Message, :count)
  end

  context 'with phone' do
    before do
      user.create_phone(iso: 'PL', prefix: '+48', number: '777777777')
    end

    it 'when user is without phone' do
      expect { subject }.to change(Message, :count).by(1)
    end

    it 'execute Communication::Sms' do
      expect_any_instance_of(Communication::Sms).to receive(:send_message)
      subject
    end

    it 'message has expected body' do
      subject
      message = Message.order(:created_at).last
      expect(message.body).to include("#{ENV['WEB_URL']}/usr/#{user.predefined_user_parameter.slug}")
    end
  end
end
