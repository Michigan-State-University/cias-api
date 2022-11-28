# frozen_string_literal: true

RSpec.describe V1::LiveChat::Interventions::UpdateNavigatorSetupService do
  subject { described_class.call(nav_setup, params) }

  let(:user) { create(:user, :admin, :confirmed) }
  let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
  let(:nav_setup) { intervention.navigator_setup }

  before { subject }

  context 'correctly updates navigator setup' do
    let(:params) do
      {
        contact_email: 'John-Paul-the-2nd@test.com'
      }
    end

    it do
      expect(nav_setup.contact_email).to eq params[:contact_email]
    end
  end

  context 'correctly updates phone param' do
    let(:intervention) { create(:intervention, :with_navigator_setup_and_phone, user: user) }

    context 'when phone exists and param is nil' do
      let(:params) do
        {
          phone: nil
        }
      end

      it do
        expect(nav_setup.reload.phone).to be nil
        expect(Phone.count).to be 0
      end
    end

    context 'when phone exists and param is not nil' do
      let(:params) do
        {
          phone: {
            number: '222333444',
            iso: 'UK',
            prefix: '+20'
          }
        }
      end

      it do
        expect(nav_setup.reload.phone).not_to be nil
        expect(nav_setup.phone.prefix).to eq params[:phone][:prefix]
        expect(nav_setup.phone.iso).to eq params[:phone][:iso]
        expect(nav_setup.phone.number).to eq params[:phone][:number]
      end
    end

    context 'when phone nil and param is not nil' do
      let(:intervention) { create(:intervention, :with_navigator_setup, user: user) }
      let(:params) do
        {
          phone: {
            iso: 'PL',
            number: '999999999',
            prefix: '+23'
          }
        }
      end

      it do
        expect(nav_setup.reload.phone).not_to be nil
        expect(nav_setup.phone.iso).to eq params[:phone][:iso]
        expect(nav_setup.phone.prefix).to eq params[:phone][:prefix]
        expect(nav_setup.phone.number).to eq params[:phone][:number]
      end
    end
  end
end
