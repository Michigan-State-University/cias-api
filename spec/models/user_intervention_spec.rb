# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserIntervention, type: :model do
  context 'UserIntervention' do
    subject { create(:user_intervention) }

    it { should belong_to(:user) }
    it { should belong_to(:intervention) }
    it { should have_many(:user_sessions) }

    it 'block to duplicate the record' do
      expect { subject.dup.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    context 'validation' do
      let(:intervention) { create(:intervention, organization: organization) }

      context 'when in an intervention in an organization' do
        let(:organization) { create(:organization, :with_health_clinics) }
        let(:health_clinic) { organization.health_clinics.sample }
        let!(:user_intervention) { create(:user_intervention, intervention: intervention, health_clinic_id: health_clinic.id) }

        it 'disallows for health_clinic_id to be nil' do
          expect { user_intervention.update!(health_clinic_id: nil) }.to raise_error(ActiveRecord::RecordInvalid)
        end

        context 'when preview' do
          let(:preview_user) { create(:user, :preview_session) }
          let!(:user_intervention) { create(:user_intervention, user: preview_user, intervention: intervention, health_clinic_id: health_clinic.id) }

          it 'allows for health_clinic_id to be nil' do
            expect(user_intervention.update!(health_clinic_id: nil)).to eq true
          end
        end
      end

      context 'when in an intervention not in an organization' do
        let(:organization) { nil }
        let!(:user_intervention) { create(:user_intervention, intervention: intervention) }

        it 'allows for health_clinic_id to be nil' do
          expect(user_intervention.update!(health_clinic_id: nil)).to eq true
        end
      end
    end
  end
end
