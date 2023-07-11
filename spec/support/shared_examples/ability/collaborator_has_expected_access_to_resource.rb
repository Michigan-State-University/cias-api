# frozen_string_literal: true

RSpec.shared_examples 'collaborator has expected access to resource' do
  it do
    expect(subject).to have_abilities({ read: true }, resource)
  end

  context 'with edit access' do
    let!(:collaborator_connection) { create(:collaborator, intervention: intervention, user: collaborator, edit: true) }

    it do
      expect(subject).to have_abilities({ manage: true }, resource)
    end
  end
end
