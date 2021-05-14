# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/generated_reports', type: :request do
  let!(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  before do
    Timecop.freeze
  end

  after do
    Timecop.return
  end

  context 'when there are generated reports' do
    let!(:intervention_owner) { user }
    let!(:intervention) { create(:intervention, user: intervention_owner) }
    let!(:session_1) { create(:session, intervention: intervention) }
    let!(:session_2) { create(:session, intervention: intervention) }
    let!(:user_session_1) { create(:user_session, user: user, session: session_1) }
    let!(:user_session_2) { create(:user_session, user: user, session: session_2) }
    let!(:participant_report) { create(:generated_report, :with_pdf_report, :participant, user_session: user_session_1) }
    let(:params) { {} }
    let!(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party, user_session: user_session_2) }

    before do
      get v1_generated_reports_path, params: params, headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
    end

    it 'returns empty list of report templates for a session' do
      expect(json_response['data']).to be_empty
    end

    context 'reports per session' do
      let(:params) { { report_for: %w[participant third_party], session_id: session_1.id } }
      let!(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party, user_session: user_session_1) }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns list of report templates for a session' do
        expect(json_response['reports_size']).to eq(2)
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
    end

    context 'report filtred by id_session for participant report' do
      let(:params) { { report_for: ['participant'], session_id: session_1.id } }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'return participant report' do
        expect(json_response['reports_size']).to eq(1)
        expect(json_response['data'].map { |data| data['id'] }).to include(participant_report.id.to_s)
      end
    end

    context 'report filtred by id_session for third part report' do
      let!(:participant_report) { create(:generated_report, :with_pdf_report, :participant, user_session: user_session_1) }
      let!(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party, user_session: user_session_2) }
      let(:params) { { report_for: %w[participant third_party], session_id: session_2.id } }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'return third party report' do
        expect(json_response['reports_size']).to eq(1)
        expect(json_response['data'].map { |data| data['id'] }).to include(third_party_report.id.to_s)
      end
    end

    context 'report_for filter is used' do
      context 'reports for participant' do
        let(:params) { { report_for: ['participant'] } }

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
        let(:params) { { report_for: ['third_party'] } }

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

    context 'order parameter is asc' do
      let(:params) { { order: 'asc', report_for: %w[participant third_party] } }
      let(:participant_report) { create(:generated_report, :with_pdf_report, :participant, created_at: 10.minutes.ago, user_session: user_session_1) }
      let(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party, created_at: 30.minutes.ago, user_session: user_session_1) }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns list in good order' do
        expected_order = [third_party_report['id'], participant_report['id']]
        returned_order = [json_response['data'][0]['id'], json_response['data'][1]['id']]
        expect(returned_order).to eq(expected_order)
      end
    end

    context 'order parameter is desc' do
      let(:params) { { order: 'desc', report_for: %w[participant third_party] } }
      let(:participant_report) { create(:generated_report, :with_pdf_report, :participant, created_at: 10.minutes.ago, user_session: user_session_1) }
      let(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party, created_at: 30.minutes.ago, user_session: user_session_1) }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns list in good order' do
        expected_order = [participant_report['id'], third_party_report['id']]
        returned_order = [json_response['data'][0]['id'], json_response['data'][1]['id']]
        expect(returned_order).to eq(expected_order)
      end
    end

    context 'with pagination' do
      let(:params) { { per_page: 1, order: 'desc', report_for: %w[participant third_party] } }
      let(:participant_report) { create(:generated_report, :with_pdf_report, :participant, created_at: 10.minutes.ago, user_session: user_session_1) }
      let(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party, created_at: 30.minutes.ago, user_session: user_session_1) }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns good first page' do
        expect(json_response['data'].size).to eq(1)
        expect(json_response['reports_size']).to eq(2)
        expect(json_response['data'].map { |data| data['id'] }).to include(participant_report.id.to_s)
      end
    end

    context 'with pagination and page' do
      let(:params) { { per_page: 1, order: 'desc', page: 2, report_for: %w[participant third_party] } }
      let(:participant_report) { create(:generated_report, :with_pdf_report, :participant, created_at: 10.minutes.ago, user_session: user_session_1) }
      let(:third_party_report) { create(:generated_report, :with_pdf_report, :third_party, created_at: 30.minutes.ago, user_session: user_session_1) }

      it 'has correct http code :ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns good second page' do
        expect(json_response['data'].size).to eq(1)
        expect(json_response['reports_size']).to eq(2)
        expect(json_response['data'].map { |data| data['id'] }).to include(third_party_report.id.to_s)
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

  context 'when intervention is created by other user' do
    let(:researcher) { create(:user, :researcher) }
    let(:intervention_owner) { researcher }

    before do
      get v1_generated_reports_path, headers: headers
    end

    it 'has correct http code :ok' do
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_empty
    end

    it 'returns empty reports list' do
      expect(json_response['data']).to be_empty
    end
  end
end
