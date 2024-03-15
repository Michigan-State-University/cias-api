# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::SendSmsInvitation do
  let(:subject) { described_class.call(user) }
  let(:intervention) { create(:intervention, :with_predefined_participants) }
  let!(:user) { intervention.predefined_users.first }

  it 'when user is without phone' do
    expect { subject }.not_to change(Message, :count)
  end

  context 'with phone' do
    before do
      user.create_phone(iso: 'PL', prefix: '+48', number: '777777777')
      allow_any_instance_of(Communication::Sms).to receive(:send_message).and_return(true)
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

    context 'with custom intervention language' do
      let!(:google_language) { create(:google_language, language_code: 'es') }
      let(:intervention) { create(:intervention, :with_predefined_participants, google_language: google_language) }

      it 'has expected message body' do
        subject
        message = Message.order(:created_at).last
        expect(message.body).to include('¡Hola! Por favor, haga clic en el enlace de abajo para comenzar o continuar su progreso en')
      end
    end

    context 'when the user is deactivated' do
      before do
        user.update!(active: false)
      end

      it 'raise an exception' do
        expect { subject }.to raise_error(ActiveRecord::ActiveRecordError)
      end
    end
  end
end
