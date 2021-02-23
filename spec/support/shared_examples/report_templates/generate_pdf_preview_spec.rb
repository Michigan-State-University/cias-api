# frozen_string_literal: true

RSpec.shared_examples 'user who is not able to generate report template pdf preview' do
  it 'returns :forbidden status and not authorized message' do
    expect(ReportTemplates::GeneratePdfPreviewJob).not_to receive(:perform_later)
    request
    expect(response).to have_http_status(:forbidden)
    expect(json_response['message']).to eq('You are not authorized to access this page.')
  end
end
