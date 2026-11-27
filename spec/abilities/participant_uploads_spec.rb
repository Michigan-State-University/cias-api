# frozen_string_literal: true

require 'rails_helper'
require 'cancan/matchers'

RSpec.describe ParticipantUpload do
  subject(:ability) { Ability.new(user) }

  let(:intervention) { create(:intervention, :published) }
  let(:session) { create(:session, intervention: intervention) }
  let(:question_group) { create(:question_group, session: session) }
  let(:question) { create(:question_file_upload, question_group: question_group) }
  let(:owner) { create(:user, :confirmed, :participant) }
  let(:user_intervention) { create(:user_intervention, user: owner, intervention: intervention) }
  let(:user_session) do
    create(:user_session, user: owner, session: session, user_intervention: user_intervention)
  end
  let(:upload) { create(:participant_upload, user_session: user_session, question: question) }

  context 'when the participant owns the session' do
    let(:user) { owner }

    it { should have_abilities(:read, upload) }
    it { should have_abilities(:create, described_class) }
    it { should have_abilities(:destroy, upload) }
  end

  context 'when another participant asks' do
    let(:user) { create(:user, :confirmed, :participant) }

    it { should not_have_abilities(:read, upload) }
    it { should not_have_abilities(:destroy, upload) }
  end

  context 'when a guest fills the intervention' do
    let(:user) { create(:user, :confirmed, :guest) }

    it { should have_abilities(:create, described_class) }
  end

  context 'when a researcher previews the session' do
    let(:user) { create(:user, :confirmed, :preview_session, preview_session_id: session.id) }
    let(:user_session) do
      create(:user_session, user: user, session: session,
                            user_intervention: create(:user_intervention, user: user, intervention: intervention))
    end

    it 'uploads like a participant' do
      expect(ability).to have_abilities(:create, described_class)
      expect(ability).to have_abilities(:read, upload)
    end
  end

  context 'when an admin from outside the intervention asks' do
    let(:user) { create(:user, :confirmed, :admin) }

    it { should not_have_abilities(:read, upload) }
    it { should not_have_abilities(:destroy, upload) }

    it 'cannot park a file in somebody else session either' do
      expect(ability).to not_have_abilities(:create, build(:participant_upload, user_session: user_session, question: question))
    end
  end

  context 'when an admin owns the intervention' do
    let(:user) { create(:user, :confirmed, :admin) }
    let(:intervention) { create(:intervention, :published, user: user) }

    it { should have_abilities(:read, upload) }
    it { should have_abilities(:get_protected_attachment, intervention) }
    it { should have_abilities(:read_upload_config, described_class) }
    it { should not_have_abilities(:destroy, upload) }

    it 'cannot park a file in a participant session it happens to own' do
      expect(ability).to not_have_abilities(:create, build(:participant_upload, user_session: user_session, question: question))
    end
  end

  context 'when a researcher owning the intervention asks' do
    let(:user) { intervention.user }

    it 'reads the file through the intervention, never through the participant resource' do
      expect(ability).to have_abilities(:get_protected_attachment, intervention)
      expect(ability).to not_have_abilities(:create, described_class)
    end

    it { should have_abilities(:read_upload_config, described_class) }
  end

  context 'when a role that never touches the upload feature asks' do
    let(:user) { create(:user, :confirmed, :navigator) }

    it { should not_have_abilities(:read_upload_config, described_class) }
  end
end
