# frozen_string_literal: true

RSpec.describe CloneJobs::Intervention, type: :job do
  subject { described_class.perform_now(user, intervention.id, clone_params) }

  let!(:user) { create(:user, :confirmed, :researcher) }
  let!(:intervention) { create(:intervention, user: user, status: 'published') }
  let!(:clone_params) { {} }

  let(:message_delivery) { instance_double(ActionMailer::MessageDelivery) }

  before do
    allow(message_delivery).to receive(:deliver_now)
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
      expect { subject }.not_to change { ActionMailer::Base.deliveries.size }
    end
  end

  context 'share intervention' do
    let(:researcher1) { create(:user, :confirmed, :researcher) }
    let(:researcher2) { create(:user, :confirmed, :researcher) }
    let!(:clone_params) do
      { emails: [
        researcher1.email,
        researcher2.email
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
      expect(Intervention.order(:created_at).last.attributes['hfhs_access']).not_to be true
    end
  end

  context 'when the invited reseacher has an activated account' do
    let!(:clone_params) { { email: [user.email] } }

    before { allow(CloneMailer).to receive(:cloned_intervention_activate).and_return(message_delivery) }

    it 'does not create a new user account' do
      expect { subject }.not_to change(User, :count)
    end

    it 'sends a proper email to the user' do
      expect(CloneMailer).to receive(:cloned_intervention)
                              .with(user, intervention.name,
                                    /^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/)
      subject
    end
  end

  context 'when the invited researcher has an account that\'s not been activated' do
    let!(:new_researcher) { create(:user, :researcher, :unconfirmed) }
    let!(:clone_params) { { emails: [new_researcher.email] } }

    before { allow(CloneMailer).to receive(:cloned_intervention_activate).and_return(message_delivery) }

    it 'does not create a new user account' do
      expect { subject }.not_to change(User, :count)
    end

    it 'sends a proper email to the user' do
      expect(CloneMailer).to receive(:cloned_intervention_activate)
                              .with(new_researcher, intervention.name,
                                    /^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/)

      subject
    end
  end

  context 'when the invited researcher doesn\'t have an account' do
    let!(:clone_params) { { emails: [Faker::Internet.unique.email] } }

    before { allow(CloneMailer).to receive(:cloned_intervention_activate).and_return(message_delivery) }

    it 'creates a new researcher account' do
      expect { subject }.to change(User, :count).by(1)
    end

    it 'sends a proper email to the researcher' do
      expect(CloneMailer).to receive(:cloned_intervention_activate)
                              .with(instance_of(User), intervention.name,
                                    /^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$/)
      subject
    end
  end
end
