# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::LiveChat::InviteNavigators do
  subject { described_class.call(emails, intervention) }

  let!(:intervention) { create(:intervention) }
  let(:emails) { ['new_email@example.com'] }

  before do
    ActiveJob::Base.queue_adapter = :test
  end

  context 'when user doesn\'t exist' do
    it {
      expect { subject }.to change(User, :count).by(1).and change(LiveChat::Interventions::NavigatorInvitation, :count).by(1)
      expect(User.find_by(email: emails.first).roles).to eq ['navigator']
    }

    it { expect { subject }.to have_enqueued_job(Navigators::InvitationJob) }
  end

  context 'when we invite researcher as navigator' do
    let!(:researcher) { create(:user, :researcher) }
    let!(:emails) { [researcher.email] }

    it {
      expect { subject }.not_to change(User, :count).and change(LiveChat::Interventions::NavigatorInvitation, :count).by(1)
      expect(researcher.reload.roles).to include('researcher', 'navigator')
    }

    it { expect { subject }.to have_enqueued_job(Navigators::InvitationJob) }
  end

  context 'when inviting existing user' do
    let!(:existing_user) { create(:user, :confirmed, :navigator) }
    let!(:invitation) { create(:navigator_invitation, intervention: intervention, email: existing_user.email) }
    let!(:emails) { [existing_user.email] }

    it do
      expect { subject }.not_to change(User, :count)
      expect(LiveChat::Interventions::NavigatorInvitation.count).to eq 1
    end
  end
end
