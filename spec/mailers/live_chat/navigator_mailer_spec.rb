# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LiveChat::NavigatorMailer, type: :mailer do
  describe 'navigator' do
    let!(:navigator) { create(:user, :confirmed, :navigator, email: 'n@viga.tor') }
    let!(:email) { navigator.email }

    let!(:intervention) { create(:intervention, status: 'published') }

    before { intervention.navigators << navigator }

    context 'call out email' do
      let!(:mail) do
        described_class.navigator_call_out_mail(email, intervention)
      end

      it 'renders the headers' do
        expect(mail.subject).to eq('Participant requested for assist!')
        expect(mail.to).to eq(['n@viga.tor'])
      end
    end

    context 'cancel call out mail' do
      let!(:mail) do
        described_class.participant_handled_mail(email, intervention)
      end

      it 'renders the headers' do
        expect(mail.subject).to eq('Participant request for assist - canceled')
        expect(mail.to).to eq(['n@viga.tor'])
      end
    end
  end
end
