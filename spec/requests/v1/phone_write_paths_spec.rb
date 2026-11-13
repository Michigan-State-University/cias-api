# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'phone normalisation on every write path', type: :request do
  let(:messy) { { iso: 'US', prefix: '+1', number: '(201) 555-0123' } }
  let(:normalised) { { 'iso' => 'US', 'prefix' => '+1', 'number' => '2015550123' } }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:intervention) { create(:intervention, user: researcher) }

  describe 'PredefinedParticipants::CreateService' do
    it 'persists the phone in normalised form' do
      params = ActionController::Parameters.new(first_name: 'Alice', last_name: 'Smith', phone_attributes: messy).permit!
      user = V1::Intervention::PredefinedParticipants::CreateService.call(intervention, params)
      expect(Phone.find(user.phone.id).slice(:iso, :prefix, :number)).to eq(normalised)
    end
  end

  describe 'POST /v1/interventions/:id/predefined_participants' do
    it 'persists the phone in normalised form' do
      post v1_intervention_predefined_participants_path(intervention_id: intervention.id),
           params: { predefined_user: { first_name: 'John', last_name: 'Doe', phone_attributes: messy } },
           headers: researcher.create_new_auth_token
      expect(response).to have_http_status(:created)
      expect(intervention.reload.predefined_users.first.phone.slice(:iso, :prefix, :number)).to eq(normalised)
    end

    it 'rejects a syntactically invalid number' do
      expect do
        post v1_intervention_predefined_participants_path(intervention_id: intervention.id),
             params: { predefined_user: { first_name: 'John', last_name: 'Doe',
                                          phone_attributes: { iso: 'PL', prefix: '+48', number: 'notanumber' } } },
             headers: researcher.create_new_auth_token
      end.to avoid_changing(Phone, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /v1/interventions/:id/predefined_participants/:id' do
    let(:participant) { create(:user, :predefined_participant, :with_phone) }

    before { PredefinedUserParameter.create(user: participant, intervention: intervention) }

    it 'persists the phone in normalised form' do
      patch v1_intervention_predefined_participant_path(intervention_id: intervention.id, id: participant.id),
            params: { predefined_user: { first_name: 'John', phone_attributes: messy } },
            headers: researcher.create_new_auth_token
      expect(response).to have_http_status(:ok)
      expect(participant.reload.phone.slice(:iso, :prefix, :number)).to eq(normalised)
    end
  end

  describe 'PATCH /v1/users/:id' do
    let(:admin) { create(:user, :confirmed, :admin) }

    it 'persists a newly nested phone in normalised form' do
      patch v1_user_path(admin.id), params: { user: { phone_attributes: messy } }, headers: admin.create_new_auth_token, as: :json
      expect(response).to have_http_status(:ok)
      expect(admin.reload.phone.slice(:iso, :prefix, :number)).to eq(normalised)
    end

    it 'persists an updated nested phone in normalised form' do
      create(:phone, user: admin)
      patch v1_user_path(admin.id), params: { user: { phone_attributes: messy } }, headers: admin.create_new_auth_token, as: :json
      expect(admin.reload.phone.slice(:iso, :prefix, :number)).to eq(normalised)
    end
  end

  describe 'alert phones' do
    let(:admin) { create(:user, :confirmed, :admin) }
    let(:alert_intervention) { create(:intervention, user: admin) }
    let(:sms_alert) { create(:sms_plan, type: 'SmsPlan::Alert', session: create(:session, intervention: alert_intervention)) }
    let(:admin_headers) { admin.create_new_auth_token }

    it 'POST normalises the created phone' do
      post v1_sms_plan_phones_path(sms_plan_id: sms_alert.id), params: { phone: messy }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:created)
      expect(sms_alert.phones.reload.last.slice(:iso, :prefix, :number)).to eq(normalised)
    end

    it 'PATCH normalises the updated phone' do
      phone = create(:phone, :confirmed, sms_plans: [sms_alert])
      patch v1_sms_plan_phone_path(sms_plan_id: sms_alert.id, id: phone.id), params: { phone: messy }, headers: admin.create_new_auth_token
      expect(response).to have_http_status(:ok)
      expect(phone.reload.slice(:iso, :prefix, :number)).to eq(normalised)
    end

    it 'PATCH keeps an alert phone confirmed when the same number is resubmitted in another format' do
      phone = create(:phone, :confirmed, sms_plans: [sms_alert], **PhoneNumberFixtures::US_MAIN)
      patch v1_sms_plan_phone_path(sms_plan_id: sms_alert.id, id: phone.id), params: { phone: messy }, headers: admin.create_new_auth_token
      expect(phone.reload).to be_confirmed
    end

    it 'still accepts a blank number through PATCH' do
      phone = create(:phone, :confirmed, sms_plans: [sms_alert])
      patch v1_sms_plan_phone_path(sms_plan_id: sms_alert.id, id: phone.id), headers: admin_headers, params: { phone: { prefix: '+1', iso: 'US', number: '' } }
      expect(response).to have_http_status(:ok)
    end
  end
end
