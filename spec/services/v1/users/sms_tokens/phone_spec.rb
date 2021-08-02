# frozen_string_literal: true

RSpec.describe V1::Users::SmsTokens::Phone do
  subject { described_class.new(user, phone_number, iso, prefix).phone }

  let!(:user) { create(:user, :confirmed) }
  let!(:phone_number) { '123456789' }
  let!(:prefix) { '48' }
  let!(:iso) { 'PL' }
  let(:phone) { Phone.last }

  context 'user does not have any phone set' do
    it 'new phone for user is added' do
      expect { subject }.to change { user.reload.phone }
    end

    it 'new phone contains proper parameters' do
      expect(user.reload.phone).to eql phone
    end
  end

  context 'user has phone set' do
    context 'but phone did not change' do
      let!(:phone) { create(:phone, number: phone_number, prefix: prefix, iso: iso, user: user) }

      it 'user phone is not changes' do
        expect { subject }.not_to change { user.reload.phone }
      end

      it 'new phone contains proper parameters' do
        expect(user.reload.phone).to eql phone
      end
    end

    context 'but phone changed' do
      let!(:old_phone) { create(:phone, number: '987654321', prefix: prefix, iso: iso, user: user) }

      it 'new phone for user is added' do
        expect { subject }.to change { user.reload.phone }.from(old_phone)
      end

      it 'new phone contains proper parameters' do
        expect(user.reload.phone).to eql phone
      end
    end
  end
end
