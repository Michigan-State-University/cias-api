# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/export', type: :request do
  let!(:user) { create(:user, :admin, :confirmed) }
  let!(:intervention) { create(:intervention) }
  let(:request) { post v1_export_intervention_path(intervention.id), headers: user.create_new_auth_token }

  context 'export intervention' do
    before do
      request
    end

    it 'returns correct status' do
      expect(response).to have_http_status(:ok)
    end

    it 'sends mail', skip: 'this test needs refactor/check' do
      expect { request }.to change(ActionMailer::Base.deliveries, :count).by 1
    end
  end

  context 'when the export job runs' do
    let!(:intervention) { create(:intervention, user: user, name: 'Exported intervention') }
    let!(:session) { create(:session, intervention: intervention, name: 'Exported session') }

    before { perform_enqueued_jobs(only: Interventions::ExportJob) { request } }

    it 'attaches a JSON export with the intervention and its sessions, without ciphertext, and lists it on the intervention' do
      exported = intervention.reload.exported_data
      expect(exported).to be_attached
      expect(exported.content_type).to eq('application/json')
      expect(exported.filename.to_s).to match(/\Aexported_.*\.json\z/)
      json = exported.download
      expect(json).to include('Exported intervention', 'Exported session')
      expect(json).not_to include('_ciphertext')

      get v1_intervention_path(intervention.id), headers: user.create_new_auth_token
      expect(json_response['data']['attributes']['exported_data']).to include(
        'url' => be_present, 'filename' => match(/\Aexported_.*\.json\z/)
      )
    end

    it 'can be imported back as a copy of the intervention' do
      upload = Rack::Test::UploadedFile.new(StringIO.new(intervention.reload.exported_data.download), 'application/json',
                                            original_filename: 'export.json')

      expect do
        perform_enqueued_jobs(only: Interventions::ImportJob) do
          post v1_import_intervention_path, params: { imported_file: { file: upload } }, headers: user.create_new_auth_token
        end
      end.to change(Intervention, :count).by(1)
      expect(response).to have_http_status(:created)

      copy = Intervention.where.not(id: intervention.id).order(:created_at).last
      expect(copy).to have_attributes(name: 'Imported Exported intervention', user_id: user.id)
      expect(copy.sessions.pluck(:name)).to eq(['Exported session'])
    end
  end
end
