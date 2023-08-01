# frozen_string_literal: true

RSpec.describe V1::Organizations::Invitations::Create, type: :request do
  subject { described_class.call(organizable, user) }

  let!(:organizable) { create(:organization) }
  let!(:user) { create(:user, :confirmed) }
  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

  before do
    allow(message_delivery).to receive(:deliver_later)
    ActiveJob::Base.queue_adapter = :test
  end

  context 'for organization' do
    before do
      allow_any_instance_of(OrganizationInvitation).to receive(:invitation_token).and_return('exampleToken')
    end

    it 'create a new invitation' do
      expect { subject }.to change(OrganizationInvitation, :count).by(1)
    end

    it 'send email with correct parameters' do
      allow(OrganizableMailer).to receive(:invite_user).with(invitation_token: 'exampleToken', email: user.email, organizable: organizable,
                                                             organizable_type: 'Organization').and_return(message_delivery)
      subject
    end

    context 'when invitation already exists' do
      let!(:invitation) { create(:organization_invitation, user: user, organization: organizable) }

      it 'didn\'t create a new one' do
        expect { subject }.not_to change(OrganizationInvitation, :count)
      end
    end

    context 'when user isn\'t confirmed' do
      let!(:user) { create(:user) }

      it 'didn\'t create an invitation' do
        expect { subject }.not_to change(OrganizationInvitation, :count)
      end
    end
  end

  context 'for health system' do
    let!(:organizable) { create(:health_system) }

    before do
      allow_any_instance_of(HealthSystemInvitation).to receive(:invitation_token).and_return('exampleToken')
    end

    it 'create a new invitation' do
      expect { subject }.to change(HealthSystemInvitation, :count).by(1)
    end

    it 'send email with correct parameters' do
      allow(OrganizableMailer).to receive(:invite_user).with(invitation_token: 'exampleToken', email: user.email, organizable: organizable,
                                                             organizable_type: 'Health System').and_return(message_delivery)
      subject
    end

    context 'when invitation already exists' do
      let!(:invitation) { create(:health_system_invitation, user: user, health_system: organizable) }

      it 'didn\'t create a new one' do
        expect { subject }.not_to change(HealthSystemInvitation, :count)
      end
    end

    context 'when user isn\'t confirmed' do
      let!(:user) { create(:user) }

      it 'didn\'t create an invitation' do
        expect { subject }.not_to change(HealthSystemInvitation, :count)
      end
    end
  end

  context 'for health clinic' do
    let!(:organizable) { create(:health_clinic) }

    before do
      allow_any_instance_of(HealthClinicInvitation).to receive(:invitation_token).and_return('exampleToken')
    end

    it 'create a new invitation' do
      expect { subject }.to change(HealthClinicInvitation, :count).by(1)
    end

    it 'send email with correct parameters' do
      allow(OrganizableMailer).to receive(:invite_user).with(invitation_token: 'exampleToken', email: user.email, organizable: organizable,
                                                             organizable_type: 'Health Clinic').and_return(message_delivery)
      subject
    end

    context 'when invitation already exists' do
      let!(:invitation) { create(:health_clinic_invitation, user: user, health_clinic: organizable) }

      it 'didn\'t create a new one' do
        expect { subject }.not_to change(HealthSystemInvitation, :count)
      end
    end

    context 'when user isn\'t confirmed' do
      let!(:user) { create(:user) }

      it 'didn\'t create an invitation' do
        expect { subject }.not_to change(HealthSystemInvitation, :count)
      end
    end
  end
end
