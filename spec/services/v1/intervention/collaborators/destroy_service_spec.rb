# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Intervention::Collaborators::DestroyService do
  subject { described_class.call(collaborator) }

  let!(:intervention) { create(:intervention, :with_collaborators) }
  let!(:collaborator) { intervention.collaborators.first }

  it 'destroy' do
    expect { subject }.to change(Collaborator, :count).by(-1)
  end

  it 'create notifications' do
    expect { subject }.to change(Notification, :count).by(1)
  end
end
