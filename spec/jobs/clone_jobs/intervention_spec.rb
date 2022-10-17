# frozen_string_literal: true

RSpec.describe CloneJobs::Intervention, type: :job do
  subject { described_class.perform_now(user, intervention.id, clone_params) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user, status: 'published') }
  let!(:clone_params) { {} }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(Intervention).to receive(:clone)
  end

  after do
    subject
  end

  context 'email notifications enabled' do
    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end
  end

  context 'email notifications disabled' do
    let!(:user) { create(:user, :confirmed, :researcher, email_notification: false) }

    it "Don't send email" do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(0)
    end
  end

  context 'share intervention' do
    let(:researcher1) { create(:user, :confirmed, :researcher) }
    let(:researcher2) { create(:user, :confirmed, :researcher) }
    let!(:clone_params) do
      { user_ids: [
        researcher1.id,
        researcher2.id
      ] }
    end

    it 'send email' do
      expect { subject }.to change { ActionMailer::Base.deliveries.size }.by(2)
    end
  end

  context 'Session::CatMh' do
    let(:intervention) do
      create(:intervention, name: 'CAT-MH', cat_mh_application_id: 'application_id', cat_mh_organization_id: 'organization_id', cat_mh_pool: 100)
    end
    let!(:session) { create(:session, intervention: intervention, position: 1) }

    it 'create a new cloned' do
      expect { subject }.to change(Intervention, :count).by(1)
    end

    it 'clear cat mh settings' do
      subject
      expect(Intervention.order(:created_at).last.attributes.slice('cat_mh_application_id', 'cat_mh_organization_id', 'cat_mh_pool',
                                                                   'created_cat_mh_session_count')).to eq(
                                                                     {
                                                                       'cat_mh_application_id' => nil,
                                                                       'cat_mh_organization_id' => nil,
                                                                       'cat_mh_pool' => nil,
                                                                       'created_cat_mh_session_count' => 0
                                                                     }
                                                                   )
    end
  end

  context 'Intervention with HFH access' do
    let!(:intervention) { create(:intervention, user: user, status: 'published', hfhs_access: true) }

    it 'does not copy over the HFH access setting' do
      subject
      expect(Intervention.order(:created_at).last.attributes['hfhs_access']).not_to eq true
    end
  end
end
