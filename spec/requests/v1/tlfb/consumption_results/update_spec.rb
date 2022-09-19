# frozen_string_literal: true

RSpec.describe 'PATCH v1/tlfb/consumption_results/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention, user: admin) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:tlfb_group, session: session) }
  let(:user_session) { create(:user_session, session: session) }
  let(:day) { create(:tlfb_day, user_session: user_session, question_group: question_group) }
  let(:consumption_result) { create(:tlfb_consumption_result, day: day) }

  let(:params) do
    {
      consumption_result: {
        body: {
          data: {
            name: 'Test name',
            unit: 'Test unit'
          }
        }
      }
    }
  end
  let(:request) { patch v1_tlfb_consumption_result_path(consumption_result.id), headers: headers, params: params }

  before { request }

  context 'When params valid' do
    it 'returns correct HTTP status (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'correctly updates substance data' do
      expect(consumption_result.reload.attributes).to include(
        'body' => {
          'data' => include(
            'unit' => 'Test unit',
            'name' => 'Test name'
          )
        }
      )
    end
  end

  context 'When params invalid' do
    let(:params) { {} }

    it 'returns correct HTTP status code (Bad Request)' do
      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'Unauthorized user' do
    let(:user) { create(:user, :participant, :confirmed) }
    let(:request) { patch v1_tlfb_consumption_result_path(consumption_result.id), headers: {}, params: params }

    it 'returns correct HTTP status code (Unauthorized)' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
