# frozen_string_literal: true

RSpec.describe DuplicateJobs::Session, type: :job do
  include ActiveJob::TestHelper
  subject { described_class.perform_now(user, session.id, new_intervention.id) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user, status: 'published') }
  let!(:new_intervention) { create(:intervention, user: user, status: 'published') }
  let!(:other_session) { create(:session, intervention: intervention) }
  let!(:session) do
    create(:session, intervention: intervention, name: 'Test', formula: { 'payload' => 'var + 5', 'patterns' => [
             { 'match' => '=8', 'target' => [{ 'id' => other_session.id, 'probability' => '100', type: 'Session' }] }
           ] })
  end
  let!(:clone_params) { {} }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Intervention).to receive(:clone)
  end

  after do
    subject
  end

  context 'email notifications enabled' do
    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  context 'email notifications disabled' do
    let!(:user) { create(:user, :confirmed, :researcher, email_notification: false) }

    it "Don't send email" do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(0)
    end
  end

  context 'assign a new session to the intervention' do
    before do
      subject
    end

    it 'add new session to intervention' do
      expect(new_intervention.reload.sessions.count).to be(1)
      expect(new_intervention.sessions.last.name).to eql(session.name)
      expect(new_intervention.sessions.last.schedule).to eql(session.schedule)
      expect(new_intervention.sessions.last.schedule_payload).to eql(session.schedule_payload)
      expect(new_intervention.sessions.last.variable).to eql("duplicated_#{session.variable}_#{new_intervention.sessions.last&.position.to_i}")
    end

    it 'have correct question group' do
      expect(new_intervention.sessions.last.question_groups.first).not_to eq(nil)
      expect(new_intervention.sessions.last.question_groups.first.title).to eq(session.question_groups.first.title)
    end

    it 'clear formula' do
      expect(new_intervention.reload.sessions.first.formula).to include(
        'payload' => '',
        'patterns' => []
      )
    end
  end

  context 'when new intervention does\'t exist' do
    subject { described_class.perform_now(user, session.id, 'wrong_id') }

    it 'did\'t create a new session' do
      expect { subject }.to avoid_changing(Session, :count)
    end
  end

  context 'when the session does\'t exist' do
    subject { described_class.perform_now(user, 'wrong_id', new_intervention.id) }

    it 'did\'t create a new session' do
      expect { subject }.to avoid_changing(Session, :count)
    end
  end
end
