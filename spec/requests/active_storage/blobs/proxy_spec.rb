# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /rails/active_storage/blobs/proxy/:signed_id/*filename', type: :request do
  let(:report) { create(:generated_report, :with_pdf_report) }
  let(:request) { get rails_storage_proxy_path(report.pdf_report, only_path: true) }

  context 'when user is not authenticated' do
    before { request }

    it 'does not return the protected pdf report' do
      pending 'BUG: blob proxy route streams pdf_report (PHI) without auth, the custom ActiveStorage::BlobsController is never used'
      expect(response.body).not_to start_with('%PDF')
    end
  end
end
