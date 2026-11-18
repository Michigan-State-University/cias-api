# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PATCH /v1/sessions/:session_id/report_template/:id', type: :request do
  let(:request) do
    patch v1_session_report_template_path(session_id: session.id, id: report_template.id),
          params: params, headers: headers
  end
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let!(:report_template) { create(:report_template, session: session) }
  let(:admin) { create(:user, :confirmed, :admin) }
  let(:admin_with_multiple_roles) { create(:user, :confirmed, roles: %w[participant admin guest]) }
  let(:user) { admin }
  let(:users) do
    {
      'admin' => admin,
      'admin_with_multiple_roles' => admin_with_multiple_roles
    }
  end
  let(:headers) { user.create_new_auth_token }
  let(:logo) { FactoryHelpers.upload_file('spec/fixtures/images/logo.png', 'image/png', true) }

  context 'one or multiple roles' do
    shared_examples 'permitted user' do
      context 'when params are valid' do
        let(:params) do
          {
            report_template: {
              name: 'New Report Template',
              report_for: 'participant',
              summary: 'Your session summary',
              logo: logo,
              duplicated_from_other_session_warning_dismissed: true
            }
          }
        end

        it 'returns :created status' do
          request
          expect(response).to have_http_status(:ok)
        end

        it 'updates report template with given attributes' do
          expect { request }.to change(ActiveStorage::Attachment, :count).by(1).and \
            change(ActiveStorage::Blob, :count).by(1).and \
              avoid_changing(ReportTemplate, :count)

          expect(ReportTemplate.last).to have_attributes(
            name: 'New Report Template',
            report_for: 'participant',
            summary: 'Your session summary',
            duplicated_from_other_session_warning_dismissed: true
          )
        end

        context 'logo is replaced' do
          before do
            report_template.update(logo: FactoryHelpers.upload_file('spec/fixtures/images/logo.png', 'image/png', true))
          end

          let(:old_logo) { report_template.logo }

          it 'updated report template attachment logo' do
            expect { request }.to change {
                                    ActiveStorage::Attachment.exists?(id: old_logo.id)
                                  }.from(true).to(false).and \
                                    avoid_changing { ActiveStorage::Attachment.count }

            expect(report_template.reload.logo).to be_present
          end
        end
      end

      context 'when params are invalid' do
        context 'when report template params are missing' do
          let(:params) { { report_template: {} } }

          it 'does not update report template, returns :bad_request status' do
            expect { request }.not_to change { report_template.reload.attributes }
            expect(response).to have_http_status(:bad_request)
          end
        end

        ['a string', %w[an array]].each do |body|
          context "when report_template is #{body.inspect}" do
            let(:params) { { report_template: body } }

            it_behaves_like 'rejects malformed params', -> { report_template.reload.attributes }
          end
        end
      end
    end

    %w[admin admin_with_multiple_roles].each do |role|
      let(:user) { users[role] }

      it_behaves_like 'permitted user'
    end
  end

  context 'when user is not super admin' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:headers) { user.create_new_auth_token }
    let(:params) do
      {
        report_template: {
          name: 'New Report Template',
          report_for: 'participant',
          summary: 'Your session summary'
        }
      }
    end

    it 'returns :forbidden status' do
      expect { request }.not_to change { report_template.reload.attributes }
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'collaboration mode' do
    let(:params) do
      {
        report_template: {
          name: 'New Report Template'
        }
      }
    end

    it_behaves_like 'collaboration mode - only one editor at the same time'
  end

  context 'when changing the type from for third party to for participant' do
    let(:user) { create(:user, :confirmed, :admin) }
    let(:intervention) { create(:intervention, user: user) }
    let(:session) { create(:session, intervention: intervention) }
    let(:report_template) { create(:report_template, session: session, report_for: :third_party) }
    let(:other_report_template) { create(:report_template, session: session, report_for: :third_party) }
    let(:question_group) { create(:question_group, session: session) }
    let(:third_party_question) { create(:question_third_party, question_group: question_group) }

    let(:params) do
      {
        report_template: {
          report_for: 'participant'
        }
      }
    end

    before do
      third_party_question.body_data.each do |data|
        data['report_template_ids'] << report_template.id
        data['report_template_ids'] << other_report_template.id
      end
      third_party_question.update!(body: third_party_question.body)
    end

    it 'correctly deletes report template id from third party questions' do
      request
      expect(third_party_question.reload.body_data.pluck('report_template_ids')).to all(eq [other_report_template.id])
    end
  end

  context 'when the owner uploads a cover letter custom logo of a third-party report' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:intervention) { create(:intervention, user: user) }
    let!(:report_template) { create(:report_template, :third_party, session: session) }
    let(:params) { { report_template: { cover_letter_custom_logo: logo } } }

    it 'attaches the file and returns its url' do
      request

      expect(response).to have_http_status(:ok)
      expect(report_template.reload.cover_letter_custom_logo).to be_attached
      expect(json_response['data']['attributes']['cover_letter_custom_logo_url']).to be_present
    end
  end

  context 'when the front sends back the whole template with read-only and stale attributes' do
    let(:user) { create(:user, :confirmed, :researcher) }
    let(:intervention) { create(:intervention, user: user) }
    let!(:section) { create(:report_template_section, report_template: report_template) }
    let!(:variant) { create(:report_template_section_variant, report_template_section: section) }
    let(:other_session) { create(:session, intervention: create(:intervention, user: user)) }
    let(:params) do
      {
        report_template: {
          id: '00000000-0000-0000-0000-000000000000',
          name: 'Renamed through PUT',
          session_id: other_session.id,
          is_duplicated_from_other_session: true,
          logo_url: 'https://example.com/evil.png',
          sections: [],
          variants: []
        }
      }
    end
    let(:request) do
      put v1_session_report_template_path(session_id: session.id, id: report_template.id),
          params: params, headers: headers, as: :json
    end

    it 'updates the permitted name only and keeps sections, variants and the session' do
      request

      expect(response).to have_http_status(:ok)
      expect(report_template.reload).to have_attributes(
        name: 'Renamed through PUT', session_id: session.id, is_duplicated_from_other_session: false
      )
      expect(report_template.sections.pluck(:id)).to eq([section.id])
      expect(report_template.variants.pluck(:id)).to eq([variant.id])
      expect(other_session.report_templates).to be_empty
    end
  end
end
