# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Intervention::Collaborators::CreateService do
  RSpec::Matchers.define_negated_matcher :not_change, :change

  subject { described_class.call(intervention, emails) }

  let!(:intervention) { create(:intervention) }
  let!(:researcher) { create(:user, :confirmed, :researcher) }
  let!(:health_clinic_admin) { create(:user, :confirmed, :health_clinic_admin) }
  let(:emails) { ['new_researcher@example.com', researcher.email, health_clinic_admin.email] }

  it 'create only 2 collaborators records' do
    expect { subject }.to change(Collaborator, :count).by(2)
  end

  it 'send two emails' do
    expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(2)
  end

  it 'create notifications' do
    expect { subject }.to change(Notification, :count).by(2)
  end

  it 'create new user' do
    expect { subject }.to change(User, :count).by(1)
  end

  it 'new account has correct role' do
    subject
    expect(User.find_by(email: 'new_researcher@example.com').roles).to include('researcher')
  end

  context 'collaborator already exist' do
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: researcher) }

    it 'raise exception and not create a new one' do
      expect { subject }.to raise_error(ActiveRecord::RecordInvalid).and not_change(Collaborator, :count)
    end
  end
end
