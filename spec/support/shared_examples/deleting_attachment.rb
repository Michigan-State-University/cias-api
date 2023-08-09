# frozen_string_literal: true

RSpec.shared_examples 'can delete attachment' do
  it 'returns the response code for no content' do
    request
    expect(response).to have_http_status(:no_content)
  end

  it 'removes the attachment' do
    expect { request }.to change(ActiveStorage::Attachment, :count).by(-1)
  end
end

RSpec.shared_examples 'cannot delete attachment' do
  it 'rejects the request' do
    request
    expect(response).to have_http_status(:forbidden)
  end

  it 'does not delete any attachments' do
    expect { request }.not_to change(ActiveStorage::Attachment, :count)
  end
end
