# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /v1/interventions/:intervention_id/tags/assign', type: :request do
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:participant) { create(:user, :confirmed, :participant) }
  let(:guest) { create(:user, :guest) }
  let(:user) { admin }
  let(:headers) { user.create_new_auth_token }

  let(:intervention_owner) { admin }
  let!(:intervention) { create(:intervention, user: intervention_owner, status: 'draft') }
  let!(:existing_tag1) { create(:tag, name: 'Existing Tag 1') }
  let!(:existing_tag2) { create(:tag, name: 'Existing Tag 2') }
  let!(:already_assigned_tag) { create(:tag, name: 'Already Assigned') }
  let!(:tag_intervention) { create(:tag_intervention, tag: already_assigned_tag, intervention: intervention) }

  let(:params) do
    {
      tag: {
        tag_ids: [existing_tag1.id, existing_tag2.id],
        names: ['New Tag 1', 'New Tag 2']
      }
    }
  end
  let(:request) { post assign_v1_intervention_tags_path(intervention.id), params: params, headers: headers }

  context 'when auth' do
    context 'is invalid' do
      let(:request) { post assign_v1_intervention_tags_path(intervention.id) }

      it_behaves_like 'unauthorized user'
    end

    context 'is valid' do
      it_behaves_like 'authorized user'
    end
  end

  context 'is response header Content-Type eq JSON' do
    before { request }

    it { expect(response.headers['Content-Type']).to eq('application/json; charset=utf-8') }
  end

  context 'when user is admin and intervention owner' do
    before { request }

    context 'when params are VALID' do
      it { expect(response).to have_http_status(:created) }

      it 'assigns existing tags by id' do
        expect(intervention.reload.tags).to include(existing_tag1, existing_tag2)
      end

      it 'creates and assigns new tags by name' do
        expect(intervention.reload.tags.pluck(:name)).to include('New Tag 1', 'New Tag 2')
      end

      it 'returns the newly assigned tags in response' do
        tag_names = json_response['data'].map { |tag| tag['attributes']['name'] }
        expect(tag_names).to include('Existing Tag 1', 'Existing Tag 2', 'New Tag 1', 'New Tag 2')
      end

      it 'does not duplicate already assigned tags' do
        expect(intervention.reload.tags.where(name: 'Already Assigned').count).to eq(1)
      end
    end

    context 'when assigning only tag_ids' do
      let(:params) do
        {
          tag: {
            tag_ids: [existing_tag1.id]
          }
        }
      end

      it 'assigns tags by id successfully' do
        expect(intervention.reload.tags).to include(existing_tag1)
      end

      it { expect(response).to have_http_status(:created) }
    end

    context 'when assigning only names' do
      let(:params) do
        {
          tag: {
            names: ['Brand New Tag']
          }
        }
      end

      it 'creates and assigns new tags' do
        expect(intervention.reload.tags.pluck(:name)).to include('Brand New Tag')
      end

      it { expect(response).to have_http_status(:created) }
    end

    context 'when tag_ids include non-existent tag' do
      let(:params) do
        {
          tag: {
            tag_ids: [999_999]
          }
        }
      end

      it 'does not assign non-existent tags' do
        initial_count = intervention.reload.tags.count
        expect(intervention.reload.tags.count).to eq(initial_count)
      end

      it { expect(response).to have_http_status(:created) }
    end

    context 'when trying to assign duplicate tag names' do
      let(:params) do
        {
          tag: {
            tag_ids: [already_assigned_tag.id]
          }
        }
      end

      it 'does not duplicate tags' do
        expect(intervention.reload.tags.where(id: already_assigned_tag.id).count).to eq(1)
      end
    end

    context 'when assigning tags with existing names' do
      let(:params) do
        {
          tag: {
            names: [existing_tag1.name]
          }
        }
      end

      it 'uses existing tag instead of creating duplicate' do
        tag_count_before = Tag.count
        request
        expect(Tag.count).to eq(tag_count_before)
      end

      it 'assigns the existing tag' do
        expect(intervention.reload.tags).to include(existing_tag1)
      end
    end
  end

  context 'when user is researcher and intervention owner' do
    let(:intervention_owner) { researcher }
    let(:user) { researcher }

    before { request }

    it { expect(response).to have_http_status(:created) }

    it 'assigns tags successfully' do
      expect(intervention.reload.tags).to include(existing_tag1, existing_tag2)
    end
  end

  context 'when user is researcher but not intervention owner' do
    let(:intervention_owner) { admin }
    let(:user) { researcher }

    before { request }

    it { expect(response).to have_http_status(:not_found) }

    it 'does not assign tags' do
      expect(intervention.reload.tags).not_to include(existing_tag1, existing_tag2)
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

    it { expect(response).to have_http_status(:created) }

    it 'assigns tags successfully' do
      expect(intervention.reload.tags.ids).to include(existing_tag1.id, existing_tag2.id)
    end
  end

  context 'when user is researcher and intervention collaborator without edit access' do
    let(:intervention_owner) { admin }
    let(:user) { researcher }
    let!(:collaborator) { create(:collaborator, intervention: intervention, user: researcher, view: true, edit: false) }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'does not assign tags' do
      expect(intervention.reload.tags).not_to include(existing_tag1, existing_tag2)
    end
  end

  context 'when user is participant' do
    let(:user) { participant }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'does not assign tags' do
      expect(intervention.reload.tags).not_to include(existing_tag1, existing_tag2)
    end
  end

  context 'when user is guest' do
    let(:user) { guest }

    before { request }

    it { expect(response).to have_http_status(:forbidden) }

    it 'does not assign tags' do
      expect(intervention.reload.tags).not_to include(existing_tag1, existing_tag2)
    end
  end

  context 'when intervention does not exist' do
    let(:request) { post assign_v1_intervention_tags_path(999_999), params: params, headers: headers }

    before do
      request
    end

    it 'returns not found status' do
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when both tag_ids and names are empty' do
    let(:params) do
      {
        tag: {
          tag_ids: [],
          names: []
        }
      }
    end

    before { request }

    it { expect(response).to have_http_status(:created) }

    it 'returns empty array' do
      expect(json_response['data']).to be_nil
    end
  end
end
