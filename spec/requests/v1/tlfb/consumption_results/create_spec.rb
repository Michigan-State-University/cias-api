# frozen_string_literal: true

RSpec.describe 'POST v1/tlfb/consumption_results', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:user) { admin }
  let(:intervention) { create(:intervention, user: admin) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:tlfb_group, session: session) }
  let!(:day) { create(:tlfb_day, user_session: user_session, question_group: question_group, exact_date: Time.zone.today) }
  let(:user_session) { create(:user_session, session: session) }
  let(:headers) { user.create_new_auth_token }

  let(:params) do
    {
      consumption_result: {
        body: {
          data: {
            name: '',
            unit: ''
          }
        },
        exact_date: day.exact_date,
        question_group_id: question_group.id,
        user_session_id: user_session.id
      }
    }
  end

  let(:request) { post v1_tlfb_consumption_results_path, headers: headers, params: params }

  before { request }

  context 'When params valid' do
    it 'returns correct HTTP status (OK)' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns correct consumption data' do
      expect(json_response['data']).to include(
        'type' => 'consumption_result',
        'attributes' => include(
          'body' => {
            'data' => include('name' => '',
                              'unit' => '')
          }
        )
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
    let(:request) { post v1_tlfb_consumption_results_path, headers: {}, params: params }

    it 'returns correct HTTP status code (Unauthorized)' do
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
