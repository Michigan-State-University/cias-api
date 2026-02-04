# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/sms_plans/:id', type: :request do
  let(:request) { patch v1_sms_plan_path(sms_plan.id), params: params, headers: headers }
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:headers) { user.create_new_auth_token }
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:sms_plan) { create :sms_plan, session: session }
  let(:params) do
    {
      sms_plan: {
        name: 'new name',
        end_at: '11/03/2021'
      }
    }
  end

  context 'when user has admin role' do
    shared_examples 'permitted user' do
      context 'valid params' do
        let(:expected_end_at) { Date.strptime('11/03/2021', '%d/%m/%Y') }

        it 'returns :ok status' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'updates sms plan attributes' do
          expect { request }.to change { sms_plan.reload.name }.from(sms_plan.name).to('new name').and \
            avoid_changing { SmsPlan.count }.and \
              change { sms_plan.reload.end_at }.from(sms_plan.end_at).to(expected_end_at)
        end
      end

      context 'invalid params' do
        let(:params) { { sms_plan: {} } }

        it 'returns :bad_request status' do
          request
          expect(response).to have_http_status(:bad_request)
        end

        it 'does not update team attributes' do
          expect { request }.not_to change(sms_plan, :name)
        end
      end

      context 'when intervention was published' do
        let(:intervention) { create(:intervention, :published) }
        let(:session) { create(:session, intervention: intervention) }

        it 'returns 405 status' do
          expect { request }.not_to change(sms_plan, :name)
          expect(response).to have_http_status(:method_not_allowed)
        end
      end

      context 'when updating to specific_time type' do
        let(:params) do
          {
            sms_plan: {
              sms_send_time_type: 'specific_time',
              sms_send_time_details: { time: '15:45' }
            }
          }
        end

        it 'returns :ok status' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'updates sms_send_time_type to specific_time' do
          expect { request }.to change { sms_plan.reload.sms_send_time_type }
                                  .from('preferred_by_participant')
                                  .to('specific_time')
        end

        it 'updates sms_send_time_details' do
          expect { request }.to change { sms_plan.reload.sms_send_time_details }
                                  .from({})
                                  .to({ 'time' => '15:45' })
        end

        it 'returns correct data in response' do
          request

          expect(json_response['data']['attributes']).to include(
            'sms_send_time_type' => 'specific_time',
            'sms_send_time_details' => { 'time' => '15:45' }
          )
        end
      end

      context 'when updating to time_range type' do
        let(:params) do
          {
            sms_plan: {
              sms_send_time_type: 'time_range',
              sms_send_time_details: { from: '10', to: '14' }
            }
          }
        end

        it 'returns :ok status' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'updates sms_send_time_type to time_range' do
          expect { request }.to change { sms_plan.reload.sms_send_time_type }
                                  .from('preferred_by_participant')
                                  .to('time_range')
        end

        it 'updates sms_send_time_details' do
          expect { request }.to change { sms_plan.reload.sms_send_time_details }
                                  .from({})
                                  .to({ 'from' => '10', 'to' => '14' })
        end
      end

      context 'when updating existing specific_time details' do
        let(:sms_plan) do
          create(:sms_plan,
                 session: session,
                 sms_send_time_type: 'specific_time',
                 sms_send_time_details: { time: '10:00' })
        end

        let(:params) do
          {
            sms_plan: {
              sms_send_time_details: { time: '16:30' }
            }
          }
        end

        it 'updates the time details' do
          expect { request }.to change { sms_plan.reload.sms_send_time_details }
                                  .from({ 'time' => '10:00' })
                                  .to({ 'time' => '16:30' })
        end

        it 'preserves the sms_send_time_type' do
          expect { request }.not_to change { sms_plan.reload.sms_send_time_type }
          expect(sms_plan.sms_send_time_type).to eq('specific_time')
        end
      end

      context 'when user wants to add image' do
        let(:params) do
          {
            sms_plan: {
              no_formula_attachment: FactoryHelpers.upload_file('spec/factories/images/test_image_1.jpg', 'image/jpeg', true)
            }
          }
        end

        it 'returns :ok status' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'attach image to the sms_plan' do
          request
          expect(sms_plan.no_formula_attachment.attached?).to be(true)
        end

        it 'returned data have correct format' do
          request
          expect(json_response['data']['attributes']['no_formula_attachment'].keys).to match_array(%w[id name url created_at])
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end

  context 'when researcher want to update sms plan with session of another researcher' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:another_user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let!(:intervention) { create(:intervention, user: another_user) }
    let(:session) { create(:session, intervention: intervention) }
    let(:params) do
      {
        sms_plan: {
          session_id: session.id
        }
      }
    end

    it 'returns :not_found status' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  it_behaves_like 'collaboration mode - only one editor at the same time'
end
