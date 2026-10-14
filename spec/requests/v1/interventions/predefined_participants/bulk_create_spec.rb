# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/predefined_participants/bulk_create', type: :request do
  let(:request) do
    post bulk_create_v1_intervention_predefined_participants_path(intervention_id: intervention.id), params: params,
                                                                                                     headers: current_user.create_new_auth_token,
                                                                                                     as: :json
  end
  let!(:intervention) { create(:intervention, user: researcher) }
  let(:researcher) { create(:user, :researcher, :confirmed) }
  let(:current_user) { researcher }
  let(:participants) do
    [
      {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john.doe@example.com',
        external_id: 'ext-1',
        email_notification: true,
        sms_notification: false,
        phone_attributes: { iso: 'US', prefix: '+1', number: '2025550123' }
      },
      {
        first_name: 'Jane',
        last_name: 'Roe',
        external_id: 'ext-2'
      }
    ]
  end
  let(:params) { { predefined_users: { participants: participants } } }
  let(:created_users) { intervention.reload.predefined_users }

  def created_user(first_name)
    created_users.find { |user| user.first_name == first_name }
  end

  context 'with valid participants' do
    before { request }

    it { expect(response).to have_http_status(:created) }

    it 'returns every created participant' do
      expect(json_response['data'].pluck('id')).to match_array(created_users.pluck(:id))
    end

    it 'creates a predefined participant for every entry' do
      expect(created_users.pluck(:first_name)).to match_array(%w[John Jane])
    end

    it 'persists nested phone attributes' do
      phone = created_user('John').phone
      expect(phone.slice(:iso, :prefix, :number)).to eq('iso' => 'US', 'prefix' => '+1', 'number' => '2025550123')
    end

    it 'persists predefined user parameters' do
      parameter = created_user('John').predefined_user_parameter
      expect(parameter.slice(:external_id, :email_notification, :sms_notification)).to eq('external_id' => 'ext-1',
                                                                                          'email_notification' => true,
                                                                                          'sms_notification' => false)
    end

    it 'creates participant without phone when phone attributes are not sent' do
      expect(created_user('Jane').phone).to be_nil
    end
  end

  context 'when participant contains unpermitted attributes' do
    let(:participants) { [{ first_name: 'John', roles: %w[admin] }] }

    before { request }

    it 'ignores them' do
      expect(created_users.first.roles).to eq %w[predefined_participant]
    end
  end

  context 'when participants list is empty' do
    let(:participants) { [] }

    it 'does not create any participant' do
      expect { request }.not_to change(User, :count)
    end
  end

  context 'when predefined_users key is missing' do
    let(:params) { { participants: participants } }

    before { request }

    it { expect(response).to have_http_status(:bad_request) }
  end

  context 'when participants are sent as a single object instead of an array' do
    let(:participants) { { first_name: 'John', last_name: 'Doe' } }

    before { request }

    it { expect(response).to have_http_status(:bad_request) }
  end

  context 'when one of participants is invalid' do
    let(:participants) do
      [
        { first_name: 'John', email: 'john.doe@example.com' },
        { first_name: 'Jane', email: 'john.doe@example.com' }
      ]
    end

    it 'does not create any participant' do
      expect { request }.not_to change(User, :count)
    end
  end

  it_behaves_like 'users without access'
end
