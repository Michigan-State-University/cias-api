# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::Intervention::AssignTags do
  describe '.call' do
    subject(:call_service) { described_class.call(intervention, tag_ids, tag_names) }

    let(:intervention) { create(:intervention) }
    let(:tag_ids) { [] }
    let(:tag_names) { [] }

    context 'when assigning tags by IDs' do
      let!(:tag1) { create(:tag, name: 'Existing Tag 1') }
      let!(:tag2) { create(:tag, name: 'Existing Tag 2') }
      let(:tag_ids) { [tag1.id, tag2.id] }

      it 'assigns the tags to the intervention' do
        expect { call_service }.to change { intervention.tags.count }.by(2)
        expect(intervention.tags).to include(tag1, tag2)
      end

      it 'returns the assigned tags' do
        result = call_service
        expect(result).to contain_exactly(tag1, tag2)
      end

      context 'when some tags are already assigned' do
        before do
          intervention.tags << tag1
        end

        it 'only assigns the new tags' do
          expect { call_service }.to change { intervention.tags.count }.by(1)
          expect(intervention.tags).to include(tag1, tag2)
        end

        it 'returns only the newly assigned tags' do
          result = call_service
          expect(result).to contain_exactly(tag2)
        end
      end

      context 'when all tags are already assigned' do
        before do
          intervention.tags << [tag1, tag2]
        end

        it 'does not assign any new tags' do
          expect { call_service }.not_to change { intervention.tags.count }
        end

        it 'returns nil' do
          result = call_service
          expect(result).to be_nil
        end
      end

      context 'when tag IDs do not exist' do
        let(:tag_ids) { [999_999, 888_888] }

        it 'does not assign any tags' do
          expect { call_service }.not_to change { intervention.tags.count }
        end

        it 'returns nil' do
          result = call_service
          expect(result).to be_nil
        end
      end
    end

    context 'when creating and assigning tags by names' do
      let(:tag_names) { ['New Tag 1', 'New Tag 2'] }

      it 'creates new tags with the given names' do
        expect { call_service }.to change(Tag, :count).by(2)
        expect(Tag.pluck(:name)).to include('New Tag 1', 'New Tag 2')
      end

      it 'assigns the created tags to the intervention' do
        expect { call_service }.to change { intervention.tags.count }.by(2)
        expect(intervention.tags.pluck(:name)).to include('New Tag 1', 'New Tag 2')
      end

      it 'returns the assigned tags' do
        result = call_service
        expect(result.pluck(:name)).to contain_exactly('New Tag 1', 'New Tag 2')
      end

      context 'when tags with the same names already exist' do
        let!(:existing_tag) { create(:tag, name: 'New Tag 1') }

        it 'does not create duplicate tags' do
          expect { call_service }.to change(Tag, :count).by(1)
        end

        it 'assigns both existing and new tags' do
          expect { call_service }.to change { intervention.tags.count }.by(2)
          expect(intervention.tags).to include(existing_tag)
          expect(intervention.tags.pluck(:name)).to include('New Tag 1', 'New Tag 2')
        end

        it 'returns the assigned tags' do
          result = call_service
          expect(result.map(&:name)).to contain_exactly('New Tag 1', 'New Tag 2')
        end
      end

      context 'when some tags by name are already assigned to the intervention' do
        let!(:existing_tag) { create(:tag, name: 'New Tag 1') }

        before do
          intervention.tags << existing_tag
        end

        it 'still creates tags that do not exist' do
          expect { call_service }.to change(Tag, :count).by(1)
        end

        it 'only assigns the new tags to intervention' do
          expect { call_service }.to change { intervention.tags.count }.by(1)
        end

        it 'returns only the newly assigned tags' do
          result = call_service
          expect(result.pluck(:name)).to contain_exactly('New Tag 2')
        end
      end
    end

    context 'when assigning tags by both IDs and names' do
      let!(:existing_tag) { create(:tag, name: 'Existing Tag') }
      let(:tag_ids) { [existing_tag.id] }
      let(:tag_names) { ['New Tag'] }

      it 'assigns tags found by ID and creates new tags by name' do
        expect { call_service }.to change(Tag, :count).by(1)
          .and change { intervention.tags.count }.by(2)
      end

      it 'assigns both types of tags to the intervention' do
        call_service
        expect(intervention.tags).to include(existing_tag)
        expect(intervention.tags.pluck(:name)).to include('Existing Tag', 'New Tag')
      end

      it 'returns all assigned tags' do
        result = call_service
        expect(result.pluck(:name)).to contain_exactly('Existing Tag', 'New Tag')
      end

      context 'when some tags are already assigned' do
        before do
          intervention.tags << existing_tag
        end

        it 'only assigns the new tags' do
          expect { call_service }.to change { intervention.tags.count }.by(1)
        end

        it 'returns only the newly assigned tags' do
          result = call_service
          expect(result.pluck(:name)).to contain_exactly('New Tag')
        end
      end
    end

    context 'when no tag IDs or names are provided' do
      let(:tag_ids) { [] }
      let(:tag_names) { [] }

      it 'does not create any tags' do
        expect { call_service }.not_to change(Tag, :count)
      end

      it 'does not assign any tags' do
        expect { call_service }.not_to change { intervention.tags.count }
      end

      it 'returns nil' do
        result = call_service
        expect(result).to be_nil
      end
    end

    context 'when tag IDs is nil' do
      let(:tag_ids) { nil }
      let(:tag_names) { ['New Tag'] }

      it 'creates and assigns tags by name only' do
        expect { call_service }.to change(Tag, :count).by(1)
          .and change { intervention.tags.count }.by(1)
      end

      it 'returns the assigned tags' do
        result = call_service
        expect(result.pluck(:name)).to contain_exactly('New Tag')
      end
    end

    context 'when tag names is nil' do
      let!(:existing_tag) { create(:tag, name: 'Existing Tag') }
      let(:tag_ids) { [existing_tag.id] }
      let(:tag_names) { nil }

      it 'does not create any new tags' do
        expect { call_service }.not_to change(Tag, :count)
      end

      it 'assigns tags by ID only' do
        expect { call_service }.to change { intervention.tags.count }.by(1)
      end

      it 'returns the assigned tags' do
        result = call_service
        expect(result).to contain_exactly(existing_tag)
      end
    end
  end
end
