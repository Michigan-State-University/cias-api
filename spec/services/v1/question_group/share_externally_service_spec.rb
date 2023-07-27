# frozen_string_literal: true

RSpec.describe V1::QuestionGroup::ShareExternallyService do
  require 'rails_helper'

  subject { described_class.new(researcher_emails, source_session_id, selected_groups_with_questions, current_user) }

  let!(:current_user) { create(:user, :researcher) }
  let!(:intervention) { create(:intervention, user_id: current_user.id) }
  let!(:session1) { create(:session, intervention: intervention) }
  let!(:session2) { create(:session, intervention: intervention) }
  let!(:researcher) { create(:user, :researcher) }

  let!(:question_group) { create(:question_group, session: session1, type: 'QuestionGroup::Plain') }
  let!(:question1) { create(:question_single, question_group: question_group) }
  let!(:question2) { create(:question_multiple, question_group: question_group) }
  let!(:question3) { create(:question_feedback, question_group: question_group) }

  let!(:selected_groups_with_questions) do
    [
      { 'id' => question_group.id, 'question_ids' => [question1.id, question3.id] }
    ]
  end
  let!(:researcher_emails) do
    [
      researcher.email.upcase
    ]
  end
  let!(:source_session_id) { session1.id }

  it 'all params are valid' do
    expect { subject.call }.to change(QuestionGroup, :count).by(2).and change(Session, :count).by(1).and change(Intervention, :count).by(1)
  end

  context 'when user hasn\'t correct ability' do
    let!(:participant) { create(:user, :participant) }
    let!(:researcher_emails) do
      [
        researcher.email, participant.email
      ]
    end

    it 'raise exception' do
      expect { subject.call }.to raise_error(CanCan::AccessDenied)
    end
  end

  context 'when the invited reseacher has an activated account' do
    let!(:invited_researcher) { create(:user, :researcher, :confirmed) }

    it 'does not create a new user account' do
      expect { subject.call }.to change(User, :count).by(0)
    end
  end

  context 'when the invited researcher has an account that\'s not been activated' do
    let!(:new_researcher) { create(:user, :researcher, :unconfirmed) }
    let!(:researcher_emails) { [new_researcher.email] }

    let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

    before do
      allow(message_delivery).to receive(:deliver_now)
      ActiveJob::Base.queue_adapter = :test
    end

    it 'does not create a new user account' do
      expect { subject.call }.to change(User, :count).by(0)
    end

    it 'sends an email to the researcher' do
      allow(CloneMailer).to receive(:cloned_question_group_activate).with(new_researcher, instance_of(String)).and_return(message_delivery)
      subject.call
    end
  end

  context 'when the invited researcher doesn\'t have an account' do
    let!(:researcher_emails) { [Faker::Internet.unique.email] }

    let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

    before do
      allow(message_delivery).to receive(:deliver_now)
      ActiveJob::Base.queue_adapter = :test
    end

    it 'creates a new researcher account' do
      expect { subject.call }.to change(User, :count).by(1)
    end

    it 'sends an email to the researcher' do
      allow(CloneMailer).to receive(:cloned_question_group_activate).with(instance_of(User), instance_of(String)).and_return(message_delivery)
      subject.call
    end
  end
end
