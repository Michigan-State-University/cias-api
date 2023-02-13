# frozen_string_literal: true

RSpec.describe Question::ThirdParty, type: :model do
  describe 'callback methods' do
    context 'it correctly downcases third party emails' do
      let(:user) { create(:user, :confirmed, :researcher) }
      let(:intervention) { create(:intervention, user: user) }
      let(:session) { create(:session, intervention: intervention) }
      let(:question_group) { create(:question_group, session: session) }
      let(:question) { create(:question_third_party, question_group: question_group) }

      it do
        question.body['data'][0]['value'] = 'HelloThere@test.pl'
        question.save!

        expect(question.body['data'][0]['value']).to eq 'hellothere@test.pl'
      end
    end
  end
end
