# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /rails/active_storage/blobs/redirect/:signed_id/*filename', type: :request do
  let(:report) { create(:generated_report, :with_pdf_report) }
  let(:request) { get rails_blob_path(report.pdf_report, only_path: true) }

  context 'when user is not authenticated' do
    before { request }

    it 'does not redirect to the protected pdf report' do
      pending 'BUG: custom ActiveStorage::BlobsController is dead code, the blob redirect route serves pdf_report (PHI) without auth'
      expect(response).not_to have_http_status(:found)
    end
  end
end
