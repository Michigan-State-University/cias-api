# frozen_string_literal: true

RSpec.describe V1::Users::Update do
  subject { described_class.call(user, user_params) }

  let!(:user) { create(:user, :confirmed) }
  let!(:user_params) do
    {
      first_name: 'John',
      last_name: 'Kowalski',
      sms_notification: false,
      description: 'Some details about user'
    }
  end

  context 'when attributes are known' do
    it 'updates user has proper attributes' do
      subject
      expect(user.first_name).to eql 'John'
      expect(user.last_name).to eql 'Kowalski'
      expect(user.sms_notification).to be false
      expect(user.description).to eql 'Some details about user'
    end
  end

  context 'when attribute is unknown' do
    let!(:user_params) do
      {
        test: 'test'
      }
    end

    it 'throws proper error message' do
      expect { subject }.to raise_error 'unknown attribute \'test\' for User.'
    end
  end
end
