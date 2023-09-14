# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::VerifyService do
  let(:subject) { described_class.call(predefined_user_parameters) }
  let!(:predefined_participant) { create(:user, :predefined_participant) }
  let(:predefined_user_parameters) { predefined_participant.predefined_user_parameter }

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
    before do
      create_list(:session, 3, intervention: predefined_user_parameters.intervention)
    end

    let(:first_session) { predefined_user_parameters.intervention.sessions.order(:position).first }


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

    context 'when session is scheduling is on' do
      before do
        user_intervention = create(:user_intervention, user: predefined_participant, intervention: predefined_user_parameters.intervention)
        create(:user_session, user: predefined_participant, session: first_session, scheduled_at: scheduled_at, user_intervention: user_intervention)
      end

      let(:scheduled_at) { DateTime.now + 2.days }

      it 'return started session' do
        expect(subject[:session_id]).to eql predefined_user_parameters.intervention.sessions.order(:position).second.id
      end

      context 'scheduled at from past' do
        let(:scheduled_at) { DateTime.now - 2.days }

        it 'return started session' do
          expect(subject[:session_id]).to eql first_session.id
        end
      end
    end
  end
end
