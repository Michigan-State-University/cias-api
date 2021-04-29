# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /v1/sessions/:session_id/report_template/:id', type: :request do
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
  let!(:session) { create :session }

  let!(:report_template) { create(:report_template, :with_logo, session: session) }
  let!(:section) { create(:report_template_section, report_template: report_template) }
  let!(:variant1) do
    create(:report_template_section_variant, report_template_section: section)
  end
  let!(:variant2) do
    create(:report_template_section_variant, report_template_section: section)
  end

  before do
    get v1_session_report_template_path(session_id: session.id, id: report_template.id),
        headers: headers
  end

  context 'one or multiple roles' do
    %w[admin admin_with_multiple_roles].each do |_role|
      context 'when there is report template with given id' do
        it 'has correct http code :ok' do
          expect(response).to have_http_status(:ok)
        end

        it 'returns report template' do
          expect(json_response['data']).to include(
            'id' => report_template.id.to_s,
            'type' => 'report_template',
            'attributes' => include(
              'name' => report_template.name,
              'report_for' => report_template.report_for,
              'summary' => report_template.summary,
              'logo_url' => include(report_template.logo.name),
              'session_id' => session.id
            ),
            'relationships' => {
              'sections' => {
                'data' => [
                  include(
                    'id' => section.id,
                    'type' => 'section'
                  )
                ]
              },
              'variants' => {
                'data' => [
                  include(
                    'id' => variant1.id,
                    'type' => 'variant'
                  ),
                  include(
                    'id' => variant2.id,
                    'type' => 'variant'
                  )
                ]
              }
            }
          )

          expect(json_response['included']).to include(
            'id' => section.id.to_s,
            'type' => 'section',
            'attributes' => include(
              'formula' => section.formula,
              'report_template_id' => report_template.id
            ),
            'relationships' => {
              'variants' => {
                'data' => [
                  include(
                    'id' => variant1.id,
                    'type' => 'variant'
                  ),
                  include(
                    'id' => variant2.id,
                    'type' => 'variant'
                  )
                ]
              }
            }
          ).and include(
            'id' => variant1.id.to_s,
            'type' => 'variant',
            'attributes' => include(
              'title' => variant1.title,
              'content' => variant1.content,
              'preview' => variant1.preview,
              'formula_match' => variant1.formula_match,
              'image_url' => nil,
              'report_template_section_id' => section.id
            )
          ).and include(
            'id' => variant2.id.to_s,
            'type' => 'variant',
            'attributes' => include(
              'title' => variant2.title,
              'content' => variant2.content,
              'preview' => variant2.preview,
              'formula_match' => variant2.formula_match,
              'image_url' => nil,
              'report_template_section_id' => section.id
            )
          )
        end
      end

      context 'when there is no report template with given id' do
        before do
          get v1_session_report_template_path(session_id: session.id, id: 'non-existing-id'),
              headers: headers
        end

        it 'has correct http code :not_found' do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
