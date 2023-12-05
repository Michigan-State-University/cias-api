# frozen_string_literal: true

RSpec.describe SessionScheduleJob, type: :job do
  let!(:session) { create(:session) }
  let!(:user_intervention) { create(:user_intervention, intervention: session.intervention, user: user) }
  let!(:user) { create(:user, :participant) }
  let(:session_id) { session.id }
  let(:user_id) { user.id }
  let(:user_intervention_id) { user_intervention.id }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Session).to receive(:find_by).with(id: session.id).and_return(session)
    allow(Session).to receive(:find_by).with(id: 'invalid_session_id').and_return(nil)
    allow(User).to receive(:find_by).with(id: user.id).and_return(user)
    allow(User).to receive(:find_by).with(id: 'invalid_user_id').and_return(nil)
  end

  after do
    described_class.new.perform(session_id, user_id, nil, user_intervention_id)
  end

  context 'when intervention is paused' do
    before do
      session.intervention.update!(status: 'paused')
    end

    it 'not send a link when intervention is published' do
      expect(session).not_to receive(:send_link_to_session)
    end
  end

  context 'user session timeout body' do
    context 'with correct session and user id' do
      it 'calls finish on perform' do
        expect(session).to receive(:send_link_to_session)
      end
    end

    context 'with incorrect session id' do
      let(:session_id) { 'invalid_session_id' }

      it 'does not call finish on perform' do
        expect_any_instance_of(Session).not_to receive(:send_link_to_session)
      end
    end

    context 'with incorrect user id' do
      let(:user_id) { 'invalid_user_id' }

      it 'does not call finish on perform' do
        expect_any_instance_of(Session).not_to receive(:send_link_to_session)
      end
    end
  end

  context 'when doesn\'t found session' do
    let(:user_intervention_id) { 'example' }

    it do
      expect_any_instance_of(UserIntervention).not_to receive(:update)
      expect_any_instance_of(Session).not_to receive(:send_link_to_session)
    end
  end
end
