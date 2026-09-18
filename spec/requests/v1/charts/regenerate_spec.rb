# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/charts/:id/regenerate', type: :request do
  let(:user) { create(:user, :confirmed, :admin) }
  let(:preview_user) { create(:user, :confirmed, :preview_session) }

  let!(:organization) { create(:organization, :with_e_intervention_admin, name: 'Michigan Public Health') }
  let!(:dashboard_section) { create(:dashboard_section, reporting_dashboard: organization.reporting_dashboard) }
  let!(:chart) do
    create(:chart, name: 'Chart', dashboard_section_id: dashboard_section.id, status: :data_collection)
  end
  let!(:e_intervention_admin) { organization.e_intervention_admins.first }

  let(:headers) { user.create_new_auth_token }
  let(:request) { post v1_regenerate_chart_path(id: chart.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post v1_regenerate_chart_path(id: chart.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is permitted' do
    shared_examples 'permitted user' do
      it 'returns accepted' do
        request

        expect(response).to have_http_status(:accepted)
      end

      # `replace` decides between a replay and a full rebuild. Asserting only "a job was enqueued"
      # cannot tell the two apart, so assert the arguments themselves. `replace: false` cannot
      # relabel an existing row (see Create#assignable?), so the button would not regenerate at all.
      it 'enqueues a full rebuild, with the triggering user' do
        expect { request }.to have_enqueued_job(RegenerateChartsJob)
          .with([chart.id], replace: true, user_id: user.id)
      end

      # The acquire lives in V1::ChartStatistics::CreateForUserSessions, which SKIPS when the lock
      # is held. A controller that acquired it would make its own job skip: 202, nothing
      # regenerated, no email, chart locked until the TTL expires.
      it 'does not take the lock itself' do
        request

        expect(chart.reload.regenerating_since).to be_nil
      end
    end

    context 'when user is admin' do
      it_behaves_like 'permitted user'
    end

    context 'when user is e-intervention admin' do
      let(:user) { e_intervention_admin }

      it_behaves_like 'permitted user'
    end
  end

  context 'when the chart is a draft' do
    let!(:chart) do
      create(:chart, name: 'Chart', dashboard_section_id: dashboard_section.id, status: :draft)
    end

    before { request }

    it 'returns unprocessable entity' do
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns the i18n refusal copy' do
      expect(json_response['message']).to eq(I18n.t('chart.error.regenerate.draft_chart'))
    end

    it 'enqueues nothing' do
      expect(RegenerateChartsJob).to have_been_enqueued.exactly(0).times
    end
  end

  context 'when the chart is already regenerating' do
    let!(:chart) do
      create(:chart, name: 'Chart', dashboard_section_id: dashboard_section.id,
                     status: :data_collection, regenerating_since: 1.minute.ago)
    end

    before { request }

    it 'returns unprocessable entity' do
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns the i18n refusal copy' do
      expect(json_response['message']).to eq(I18n.t('chart.error.regenerate.in_progress'))
    end

    it 'enqueues nothing' do
      expect(RegenerateChartsJob).to have_been_enqueued.exactly(0).times
    end
  end

  # A lock older than the TTL is not a lock — the service will take it. Refusing on a stale
  # timestamp would grey the button out permanently after a SIGKILL, which is the wedge the
  # timestamp column exists to avoid.
  context 'when a previous lock has outlived the TTL' do
    let!(:chart) do
      create(:chart, name: 'Chart', dashboard_section_id: dashboard_section.id, status: :data_collection,
                     regenerating_since: (V1::ChartStatistics::CreateForUserSessions::LOCK_TTL + 1.minute).ago)
    end

    it 'accepts the request' do
      request

      expect(response).to have_http_status(:accepted)
    end

    it 'enqueues the job' do
      expect { request }.to have_enqueued_job(RegenerateChartsJob)
    end
  end

  context 'when the chart is outside the user scope' do
    let(:other_organization) { create(:organization) }
    let(:other_section) { create(:dashboard_section, reporting_dashboard: other_organization.reporting_dashboard) }
    let!(:other_chart) do
      create(:chart, dashboard_section_id: other_section.id, status: :data_collection)
    end
    let(:user) { e_intervention_admin }
    let(:request) { post v1_regenerate_chart_path(id: other_chart.id), headers: headers }

    before { request }

    it 'returns not found' do
      expect(response).to have_http_status(:not_found)
    end

    it 'enqueues nothing' do
      expect(RegenerateChartsJob).to have_been_enqueued.exactly(0).times
    end
  end

  context 'when user is not permitted' do
    shared_examples 'unpermitted user' do
      before { request }

      it 'returns forbidden' do
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns proper error message' do
        expect(json_response['message']).to eq('You are not authorized to access this page.')
      end

      it 'enqueues nothing' do
        expect(RegenerateChartsJob).to have_been_enqueued.exactly(0).times
      end
    end

    %i[health_system_admin organization_admin team_admin researcher participant guest
       health_clinic_admin].each do |role|
      context "user is #{role}" do
        let(:user) { create(:user, :confirmed, role) }

        it_behaves_like 'unpermitted user'
      end
    end

    # The roles above are outside this organization, so `chart_load` would 404 for them even with
    # no `authorize!` at all. This one is INSIDE the read scope `charts_scope` uses, so only the
    # class-level gate refuses it.
    context 'when user is an organization admin of this organization' do
      let(:user) { create(:user, :confirmed, :organization_admin, organizable: organization) }

      before { organization.organization_admins << user }

      it_behaves_like 'unpermitted user'
    end

    context 'when user is preview user' do
      let(:headers) { preview_user.create_new_auth_token }

      before { request }

      it_behaves_like 'preview user'
    end
  end
end
