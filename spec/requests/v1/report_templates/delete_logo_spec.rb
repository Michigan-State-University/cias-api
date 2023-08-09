# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DELETE v1/sessions/:session_id/report_templates/:id/remove_logo', type: :request do
  let(:intervention) { create(:intervention) }
  let(:session) { create(:session, intervention: intervention) }
  let(:user) { create(:user, :researcher, :confirmed) }

  let(:headers) { user.create_new_auth_token }

  let(:request) do
    delete v1_session_report_template_remove_logo_path(
      session_id: session.id, report_template_id: report_template.id
    ), headers: headers
  end

  let!(:report_template) { create(:report_template, :with_logo, session: session) }

  context 'when an admin deletes the report logo' do
    let!(:user) { create(:user, :admin, :confirmed) }

    it_behaves_like 'can delete attachment'
  end

  context 'when a researcher tries to delete the custom logo of a session which is not theirs' do
    it_behaves_like 'cannot delete attachment'
  end

  context 'when a participant tries to delete the report logo of their session' do
    let!(:intervention) { create(:intervention, user: user) }

    it_behaves_like 'can delete attachment'
  end

  context 'when the report is for a collaborative session' do
    let(:user) { create(:user, :researcher, :confirmed) }

    context 'when the user is the current editor' do
      let!(:intervention) { create(:intervention, :with_collaborators, user: user, current_editor: user) }

      it_behaves_like 'can delete attachment'
    end

    context 'when the user is not the current editor' do
      let(:other_user) { create(:user, :researcher, :confirmed) }
      let!(:intervention) { create(:intervention, :with_collaborators, user: user, current_editor: other_user) }

      it_behaves_like 'cannot delete attachment'
    end
  end
end
