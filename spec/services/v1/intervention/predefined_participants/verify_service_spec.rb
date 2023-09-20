# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::VerifyService do
  let(:subject) { described_class.call(predefined_user_parameters) }
  let!(:predefined_participant) { create(:user, :predefined_participant) }
  let(:predefined_user_parameters) { predefined_participant.predefined_user_parameter }
  let(:first_session) { predefined_user_parameters.intervention.sessions.order(:position).first }

  it 'return expected response' do
    expect(subject.keys).to match_array(%i[intervention_id session_id health_clinic_id multiple_fill_session_available user_intervention_id])
  end

  context 'first execution of this service for the user' do
    it 'create user intervention for the user' do
      expect { subject }.to change(UserIntervention, :count).by(1)
    end

    it 'when intervention deesn\'t have sessions' do
      expect(subject[:session_id]).to be nil
    end
  end

  context 'intervention with sessions' do
    let(:second_session) { predefined_user_parameters.intervention.sessions.order(:position).second }

    before do
      create_list(:session, 3, intervention: predefined_user_parameters.intervention)
    end

    it 'when intervention deesn\'t have sessions' do
      expect(subject[:session_id]).to eql first_session.id
    end

    context 'with started user session' do
      before do
        user_intervention = create(:user_intervention, user: predefined_participant, intervention: predefined_user_parameters.intervention)
        create(:user_session, user: predefined_participant, session: first_session, user_intervention: user_intervention)
      end

      it 'return started session' do
        expect(subject[:session_id]).to eql first_session.id
      end
    end

    context 'when first user session is completed' do
      before do
        user_intervention = create(:user_intervention, user: predefined_participant, intervention: predefined_user_parameters.intervention)
        create(:user_session, user: predefined_participant, session: first_session, finished_at: DateTime.now, user_intervention: user_intervention)
      end

      it 'return started session' do
        expect(subject[:session_id]).to eql second_session.id
      end
    end

    context 'when session is scheduling is on' do
      before do
        user_intervention = create(:user_intervention, user: predefined_participant, intervention: predefined_user_parameters.intervention)
        create(:user_session, user: predefined_participant, session: first_session, finished_at: DateTime.now, user_intervention: user_intervention)
        create(:user_session, user: predefined_participant, session: second_session, scheduled_at: scheduled_at, user_intervention: user_intervention)
      end

      let(:scheduled_at) { DateTime.now + 2.days }

      it 'return started session' do
        expect(subject[:session_id]).to be nil
      end

      context 'scheduled at from past' do
        let(:scheduled_at) { DateTime.now - 2.days }

        it 'return started session' do
          expect(subject[:session_id]).to eql second_session.id
        end
      end
    end

    context 'when intervention is completed' do
      before do
        create(:user_intervention, user: predefined_participant, intervention: predefined_user_parameters.intervention, status: :completed)
      end

      it 'return started session' do
        expect(subject[:session_id]).to be nil
      end
    end
  end

  context 'flexible intervention' do
    let(:user_intervention) { create(:user_intervention, user: predefined_participant, intervention: predefined_user_parameters.intervention) }
    let(:user_session) { create(:user_session, user: predefined_participant, session: first_session, user_intervention: user_intervention) }

    before do
      predefined_user_parameters.intervention.update!(type: 'Intervention::FlexibleOrder')
      create_list(:session, 3, intervention: predefined_user_parameters.intervention)
      first_session.update!(multiple_fill: true)
      user_session
    end

    it 'return current user_session' do
      expect(subject[:session_id]).to eql first_session.id
      expect(subject[:multiple_fill_session_available]).to be false
    end

    context 'all user sessions are finished' do
      before do
        user_session.finish
      end

      it 'return correct value for some keys' do
        expect(subject[:session_id]).to be nil
        expect(subject[:multiple_fill_session_available]).to be true
      end
    end

    context 'multiple-fill session is finished but next session is already started' do
      let(:second_user_session) do
        create(:user_session, session: predefined_user_parameters.intervention.sessions.order(:position).second, user: predefined_participant,
                              user_intervention: user_intervention)
      end

      before do
        user_session.finish
        second_user_session
      end

      it 'multiple fill session available should return nil if user has other session in progress' do
        expect(subject[:multiple_fill_session_available]).to be false
      end
    end
  end
end
