# frozen_string_literal: true

RSpec.describe V1::Intervention::PredefinedParticipants::VerifyService do
  context 'with a predefined participant created up front' do
    subject { described_class.call(predefined_user_parameters) }

    let!(:predefined_participant) { create(:user, :predefined_participant) }
    let(:predefined_user_parameters) { predefined_participant.predefined_user_parameter }
    let(:first_session) { predefined_user_parameters.intervention.sessions.order(:position).first }

    it 'return expected response' do
      expect(subject.keys).to match_array(%i[intervention_id session_id health_clinic_id multiple_fill_session_available user_intervention_id lang
                                             intervention_type ra_session_pending])
    end

    context 'first execution of this service for the user' do
      it 'create user intervention for the user' do
        expect { subject }.to change(UserIntervention, :count).by(1)
      end

      it 'when intervention doesn\'t have sessions' do
        expect(subject[:session_id]).to be_nil
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
          expect(subject[:session_id]).to be_nil
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
          expect(subject[:session_id]).to be_nil
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
          expect(subject[:session_id]).to be_nil
          expect(subject[:multiple_fill_session_available]).to be true
        end
      end

      context 'multiple-fill session is finished but next session is already started' do
        let(:second_user_session) do
          create(:user_session, session: predefined_user_parameters.intervention.sessions.order(:position).second, user: predefined_participant,
                                user_intervention: user_intervention, started: true)
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

    context 'flexible intervention inside organization' do
      let(:organization) { create(:organization, :with_health_clinics) }

      before do
        intervention = predefined_user_parameters.intervention
        intervention.update!(organization: organization, type: 'Intervention::FlexibleOrder')
        predefined_user_parameters.update!(health_clinic: organization.health_systems.first.health_clinics.first)
      end

      it 'return user intervention' do
        expect { subject }.to change(UserIntervention, :count).by(1)
      end
    end
  end

  describe 'link opening' do
    include ActiveSupport::Testing::TimeHelpers

    subject(:call_service) { described_class.call(predefined_user_parameter) }

    let(:predefined_participant) { create(:user, :predefined_participant) }
    let(:predefined_user_parameter) { predefined_participant.predefined_user_parameter }
    let(:opened_at) { Time.zone.local(2026, 11, 2, 9, 30, 0) }
    let(:first_visit_at) { Time.zone.local(2026, 11, 2, 9, 0, 0) }

    describe 'first_opened_at stamp' do
      it 'starts without a stamp' do
        expect(predefined_user_parameter.first_opened_at).to be_nil
      end

      it 'stamps first_opened_at with the current time when it is nil' do
        travel_to(opened_at) { call_service }

        expect(predefined_user_parameter.reload.first_opened_at).to be_within(1.second).of(opened_at)
      end

      it 'does not overwrite the stamp on a second call' do
        travel_to(opened_at) { described_class.call(predefined_user_parameter) }
        travel_to(opened_at + 3.days) { described_class.call(predefined_user_parameter.reload) }

        expect(predefined_user_parameter.reload.first_opened_at).to be_within(1.second).of(opened_at)
      end

      it 'does not overwrite a stamp that already exists' do
        earlier = opened_at - 10.days
        predefined_user_parameter.update_column(:first_opened_at, earlier)

        travel_to(opened_at) { call_service }

        expect(predefined_user_parameter.reload.first_opened_at).to be_within(1.second).of(earlier)
      end

      it 'does not overwrite a stamp written after the participant was loaded' do
        stale = PredefinedUserParameter.find(predefined_user_parameter.id)
        earlier = opened_at - 1.day
        predefined_user_parameter.update_column(:first_opened_at, earlier)

        travel_to(opened_at) { described_class.call(stale) }

        expect(predefined_user_parameter.reload.first_opened_at).to be_within(1.second).of(earlier)
      end

      it 'stamps through update_column, leaving updated_at untouched' do
        predefined_user_parameter.update_column(:updated_at, opened_at - 5.days)
        expected_updated_at = predefined_user_parameter.reload.updated_at

        travel_to(opened_at) { call_service }
        predefined_user_parameter.reload

        expect(predefined_user_parameter.first_opened_at).to be_present
        expect(predefined_user_parameter.updated_at).to be_within(1.second).of(expected_updated_at)
      end

      it 'does not stamp last_reminder_sent_at' do
        travel_to(opened_at) { call_service }

        expect(predefined_user_parameter.reload.last_reminder_sent_at).to be_nil
      end

      it 'stamps only the participant whose parameters were passed' do
        other = create(:user, :predefined_participant).predefined_user_parameter

        travel_to(opened_at) { call_service }

        expect(other.reload.first_opened_at).to be_nil
      end

      it 'still returns the redirect payload' do
        expect(travel_to(first_visit_at) { call_service }.keys).to match_array(
          %i[intervention_id session_id health_clinic_id multiple_fill_session_available user_intervention_id lang intervention_type ra_session_pending]
        )
      end
    end
  end
end
