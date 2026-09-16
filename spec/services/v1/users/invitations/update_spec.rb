# frozen_string_literal: true

RSpec.describe V1::Users::Invitations::Update do
  subject { described_class.call(invitation_params) }

  let!(:invitation_token) { 'EYKPJ9P5y2Kc3Jp7juvq' }
  let!(:password) { 'kytdhdn#@!124' }
  let!(:user) do
    create(:user, :researcher, email: 'test@example.com',
                               invitation_token: Devise.token_generator.digest(self, :invitation_token, invitation_token),
                               invitation_accepted_at: nil)
  end

  let!(:invitation_params) do
    {
      invitation_token: invitation_token,
      password: password,
      password_confirmation: password,
      first_name: 'John',
      last_name: 'Doe'
    }
  end

  context 'invitation params are valid' do
    it 'updates user' do
      subject

      expect(user.reload.invitation_token).to be_nil
      expect(user.reload.invitation_accepted_at).to be_present
      expect(user.confirmed_at).to be_present
    end
  end

  context 'invitation params are invalid' do
    context 'invitation token is invalid' do
      let(:invitation_token) { 'invalid' }

      it 'does not update user' do
        expect { subject }.to avoid_changing { user }
      end
    end
  end
end
