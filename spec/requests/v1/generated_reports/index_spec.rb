# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/generated_reports', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  before do
    Timecop.freeze
  end

  after do
    Timecop.return
  end

  context 'when there are generated reports' do
    let!(:participant_report) { create(:generated_report, :with_pdf_report, :participant) }
    let(:params) { {} }
    let!(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party) }

    before do
      get v1_generated_reports_path, params: params, headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns list of report templates for a session' do
      expect(json_response['data']).to include(
        'id' => participant_report.id.to_s,
        'type' => 'generated_report',
        'attributes' => include(
          'name' => participant_report.name,
          'report_for' => 'participant',
          'pdf_report_url' => include('example_report.pdf'),
          'created_at' => Time.current.iso8601
        )
      ).and include(
        'id' => third_party_report.id.to_s,
        'type' => 'generated_report',
        'attributes' => include(
          'name' => third_party_report.name,
          'report_for' => 'third_party',
          'pdf_report_url' => include('example_report.pdf'),
          'created_at' => Time.current.iso8601
        )
      )
    end

    context 'report_for filter is used' do
      context 'reports for participant' do
        let(:params) { { report_for: 'participant' } }

        it 'has correct http code :ok' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns list of report templates for a session' do
          expect(json_response['data'].size).to eq(1)
          expect(json_response['data'].map { |data| data['id'] }).to include(participant_report.id.to_s).and \
            not_include(third_party_report.id.to_s)
        end
      end

      context 'reports for third_party' do
        let(:params) { { report_for: 'third_party' } }

        it 'has correct http code :ok' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns list of report templates for a session' do
          expect(json_response['data'].size).to eq(1)
          expect(json_response['data'].map { |data| data['id'] }).to include(third_party_report.id.to_s).and \
            not_include(participant_report.id.to_s)
        end
      end
    end
  end

  context 'when there are no generated reports' do
    before do
      get v1_generated_reports_path, headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_empty
    end
  end
end
