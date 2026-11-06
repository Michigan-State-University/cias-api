# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE /v1/report_templates/sections/:section_id/variants/:variant_id/remove_image', type: :request do
  let(:request) do
    delete v1_report_template_section_variant_remove_image_path(
      section_id: report_template_section.id,
      variant_id: variant.id
    ), headers: headers
  end
  let(:researcher) { create(:user, :confirmed, :researcher) }
  let(:intervention) { create(:intervention, user: researcher) }
  let(:session) { create(:session, intervention: intervention) }
  let(:report_template) { create(:report_template, session: session) }
  let(:report_template_section) { create(:report_template_section, report_template: report_template) }
  let!(:variant) do
    create(:report_template_section_variant, :with_image, report_template_section: report_template_section)
  end
  let(:user) { create(:user, :confirmed, :admin) }
  let(:headers) { user.create_new_auth_token }

  shared_examples 'removes the image' do
    it 'returns :ok status' do
      request
      expect(response).to have_http_status(:ok)
    end

    it 'purges the variant image' do
      expect { request }.to change { variant.reload.image.attached? }.from(true).to(false).and \
        change(ActiveStorage::Attachment, :count).by(-1)
    end

    it 'does not remove the variant' do
      expect { request }.not_to change(ReportTemplate::Section::Variant, :count)
    end
  end

  shared_examples 'does not remove the image' do |status|
    it "returns :#{status} status and keeps the image" do
      expect { request }.not_to change(ActiveStorage::Attachment, :count)
      expect(response).to have_http_status(status)
      expect(variant.reload.image).to be_attached
    end
  end

  context 'when user is not authenticated' do
    let(:headers) { {} }

    it_behaves_like 'unauthorized user'
  end

  context 'when user is an admin' do
    it_behaves_like 'removes the image'
  end

  context 'when user is the researcher who owns the intervention' do
    let(:user) { researcher }

    it_behaves_like 'removes the image'
  end

  context 'when variant has no image' do
    let!(:variant) { create(:report_template_section_variant, report_template_section: report_template_section) }

    it 'returns :ok status' do
      request
      expect(response).to have_http_status(:ok)
      expect(variant.reload.image).not_to be_attached
    end
  end

  context 'when user is a researcher without access to the intervention' do
    let(:user) { create(:user, :confirmed, :researcher) }

    it_behaves_like 'does not remove the image', :forbidden
  end

  context 'when user is a participant' do
    let(:user) { create(:user, :confirmed, :participant) }

    it_behaves_like 'does not remove the image', :forbidden
  end

  context 'when variant belongs to another section' do
    let(:other_section) { create(:report_template_section, report_template: report_template) }
    let!(:variant) do
      create(:report_template_section_variant, :with_image, report_template_section: other_section)
    end
    let(:request) do
      delete v1_report_template_section_variant_remove_image_path(
        section_id: create(:report_template_section, report_template: report_template).id,
        variant_id: variant.id
      ), headers: headers
    end

    it_behaves_like 'does not remove the image', :not_found
  end

  context 'when the intervention has collaborators' do
    let(:user) { researcher }

    context 'when the user is the current editor' do
      let(:intervention) { create(:intervention, :with_collaborators, user: researcher, current_editor: researcher) }

      it_behaves_like 'removes the image'
    end

    context 'when the user is not the current editor' do
      let(:intervention) do
        create(:intervention, :with_collaborators, user: researcher, current_editor: create(:user, :confirmed, :researcher))
      end

      it_behaves_like 'does not remove the image', :forbidden
    end
  end
end
