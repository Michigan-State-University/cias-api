# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/interventions/:intervention_id/tags/:id', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }

  let(:intervention_owner) { admin }
  let!(:intervention) { create(:intervention, user: intervention_owner, status: 'draft') }
  let!(:tag) { create(:tag, name: 'Tag to Remove') }
  let!(:tag_intervention) { create(:tag_intervention, tag: tag, intervention: intervention) }

  let(:request) { delete v1_intervention_tag_path(intervention.id, tag.id), headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { delete v1_intervention_tag_path(intervention.id, tag.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'when user is admin and intervention owner' do
    before { request }

    context 'when tag is assigned to intervention' do
      it { expect(response).to have_http_status(:no_content) }

      it 'removes the tag from intervention' do
        expect(intervention.reload.tags).not_to include(tag)
      end

      it 'removes TagIntervention association' do
        expect(TagIntervention.find_by(tag_id: tag.id, intervention_id: intervention.id)).to be_nil
      end

      it 'does not delete the tag itself' do
        expect(Tag.find_by(id: tag.id)).not_to be_nil
      end
    end
  end

  context 'when tag is not assigned to intervention' do
    let!(:unassigned_tag) { create(:tag, name: 'Unassigned Tag') }
    let(:request) { delete v1_intervention_tag_path(intervention.id, unassigned_tag.id), headers: headers }

    before { request }

    it { expect(response).to have_http_status(:no_content) }

    it 'does not affect intervention tags' do
      expect(intervention.reload.tags).to include(tag)
    end
  end

  context 'when tag does not exist' do
    let(:request) { delete v1_intervention_tag_path(intervention.id, 999_999), headers: headers }

    before { request }

    it { expect(response).to have_http_status(:no_content) }

    it 'does not affect intervention tags' do
      expect(intervention.reload.tags).to include(tag)
    end
  end

  context 'when user is researcher and intervention owner' do
    let(:intervention_owner) { researcher }
    let(:user) { researcher }

    before { request }

    it { expect(response).to have_http_status(:no_content) }

    it 'removes the tag from intervention' do
      expect(intervention.reload.tags).not_to include(tag)
    end
  end

  context 'when user is researcher but not intervention owner' do
    let(:intervention_owner) { admin }
    let(:user) { researcher }

    before { request }

    it { expect(response).to have_http_status(:not_found) }

    it 'does not remove the tag' do
      expect(intervention.reload.tags).to include(tag)
    end
  end

  context 'when user is researcher and intervention collaborator with edit access' do
    let(:intervention_owner) { admin }
    let(:user) { researcher }
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: researcher, view: true, edit: true) }

    before do
      intervention.update(current_editor_id: researcher.id)
      request
    end

    it { expect(response).to have_http_status(:no_content) }

    it 'removes the tag from intervention' do
      expect(intervention.reload.tags).not_to include(tag)
    end
  end

  context 'when user is researcher and intervention collaborator without edit access' do
    let(:intervention_owner) { admin }
    let(:user) { researcher }
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: researcher, view: true, edit: false) }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'does not remove the tag' do
      expect(intervention.reload.tags).to include(tag)
    end
  end

  context 'when user is participant' do
    let(:user) { participant }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'does not remove the tag' do
      expect(intervention.reload.tags).to include(tag)
    end
  end

  context 'when user is guest' do
    let(:user) { guest }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'does not remove the tag' do
      expect(intervention.reload.tags).to include(tag)
    end
  end

  context 'when intervention does not exist' do
    let(:request) { delete v1_intervention_tag_path(999_999, tag.id), headers: headers }

    it 'returns not found error' do
      request
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when multiple tags are assigned' do
    let!(:tag2) { create(:tag, name: 'Tag 2') }
    let!(:tag3) { create(:tag, name: 'Tag 3') }
    let!(:tag_intervention2) { create(:tag_intervention, tag: tag2, intervention: intervention) }
    let!(:tag_intervention3) { create(:tag_intervention, tag: tag3, intervention: intervention) }

    before { request }

    it 'removes only the specified tag' do
      expect(intervention.reload.tags).not_to include(tag)
      expect(intervention.reload.tags).to include(tag2, tag3)
    end

    it { expect(response).to have_http_status(:no_content) }
  end

  context 'when tag is assigned to multiple interventions' do
    let!(:intervention2) { create(:intervention, user: admin) }
    let!(:tag_intervention2) { create(:tag_intervention, tag: tag, intervention: intervention2) }

    before { request }

    it 'removes tag only from specified intervention' do
      expect(intervention.reload.tags).not_to include(tag)
      expect(intervention2.reload.tags).to include(tag)
    end

    it { expect(response).to have_http_status(:no_content) }
  end
end
