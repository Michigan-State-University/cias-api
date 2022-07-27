# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/downloaded_report', type: :request do
  context 'for participant' do
    let!(:user) { create(:user, :confirmed, :participant) }
    let(:headers) { user.create_new_auth_token }

    let!(:participant_report) { create(:generated_report, :participant) }
    let(:params) do
      {
        report_id: participant_report.id
      }
    end
    let(:request) { post v1_downloaded_reports_path, params: params, headers: headers }

    context 'when auth' do
      context 'is invalid' do
        let(:request) { post v1_downloaded_reports_path }

        it_behaves_like 'unauthorized user'
      end

      context 'is valid' do
        it_behaves_like 'authorized user'
      end
    end

    context 'when user is permitted' do
      before { request }

      it 'returns correct status' do
        expect(response).to have_http_status(:created)
        expect(DownloadedReport.count).to eq(1)
      end

      it 'returns proper data' do
        expect(json_response['data']['attributes']).to include(
          {
            'user_id' => user.id,
            'generated_report_id' => participant_report.id,
            'downloaded' => true
          }
        )
      end
    end

    context 'when report id is invalid' do
      it_behaves_like 'authorized user'

      context 'when report_id is invalid' do
        let!(:params) do
          {
            report_id: Faker::Internet.uuid
          }
        end

        let!(:request) { post v1_downloaded_reports_path, params: params, headers: headers }

        it { expect(response).to have_http_status(:unprocessable_entity) }

        it 'response contains proper error message' do
          expect(json_response['message']).to eq 'Validation failed: Generated report must exist'
        end
      end

      context 'when report_id is empty' do
        let!(:params) do
          {
            report_id: ''
          }
        end

        let!(:request) { post v1_downloaded_reports_path, params: params, headers: headers }

        it { expect(response).to have_http_status(:bad_request) }
      end
    end

    context 'when report was already marked as downloaded' do
      before { request }

      let!(:request2) { post v1_downloaded_reports_path, params: params, headers: headers }

      it 'returns correct status' do
        expect(response).to have_http_status(:ok)
        expect(DownloadedReport.count).to eq(1)
      end

      it 'returns proper data' do
        expect(json_response['data']['attributes']).to include(
          {
            'user_id' => user.id,
            'generated_report_id' => participant_report.id,
            'downloaded' => true
          }
        )
      end
    end
  end

  context 'for third party' do
    let!(:user) { create(:user, :confirmed, :third_party) }
    let(:headers) { user.create_new_auth_token }

    let!(:third_party_report) { create(:generated_report, :third_party) }
    let(:params) do
      {
        report_id: third_party_report.id
      }
    end
    let(:request) { post v1_downloaded_reports_path, params: params, headers: headers }

    context 'when auth' do
      context 'is invalid' do
        let(:request) { post v1_downloaded_reports_path }

        it_behaves_like 'unauthorized user'
      end

      context 'is valid' do
        it_behaves_like 'authorized user'
      end
    end

    context 'when user is permitted' do
      before { request }

      it 'returns correct status' do
        expect(response).to have_http_status(:created)
        expect(DownloadedReport.count).to eq(1)
      end

      context 'when user is permitted' do
        before { request }

        it 'returns correct status' do
          expect(response).to have_http_status(:created)
          expect(DownloadedReport.count).to eq(1)
        end

        it 'returns proper data' do
          expect(json_response['data']['attributes']).to include(
            {
              'user_id' => user.id,
              'generated_report_id' => third_party_report.id,
              'downloaded' => true
            }
          )
        end
      end
    end
  end

  context 'for others' do
    let!(:user) { create(:user, :confirmed) }
    let(:headers) { user.create_new_auth_token }

    let!(:report) { create(:generated_report) }
    let(:params) do
      {
        report_id: report.id
      }
    end
    let(:request) { post v1_downloaded_reports_path, params: params, headers: headers }

    context 'when marks report as downloaded' do
      before { request }

      it 'returns correct status' do
        expect(response).to have_http_status(:created)
        expect(DownloadedReport.count).to eq(1)
      end

      it 'returns proper data' do
        expect(json_response['data']['attributes']).to include(
          {
            'user_id' => user.id,
            'generated_report_id' => report.id,
            'downloaded' => true
          }
        )
      end
    end
  end
end
