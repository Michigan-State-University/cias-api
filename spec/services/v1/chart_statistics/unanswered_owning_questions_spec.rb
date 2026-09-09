# frozen_string_literal: true

# The class had no unit spec until 2026-09-04, which meant every change to it flew blind at
# unit level. Both predicates are covered here:
#
#   `none_answered?` - the live ungated rule (drop only the participant who answered NONE of
#                      the questions owning the formula's missing variables).
#   `call`           - the retired strict rule (drop when ANY owning question is unanswered),
#                      retained on the class so the gated path can adopt it.
RSpec.describe V1::ChartStatistics::UnansweredOwningQuestions do
  let(:organization) { create(:organization) }
  let(:health_system) { create(:health_system, organization: organization) }
  let(:health_clinic) { create(:health_clinic, health_system: health_system) }
  let(:intervention) { create(:intervention, :published, organization: organization) }
  let(:user) { create(:user, :participant, :confirmed) }
  let(:user_intervention) { create(:user_intervention, user: user, intervention: intervention, health_clinic_id: health_clinic.id) }

  let(:session) { create(:session, intervention: intervention, variable: 'ht1') }
  let(:question_group) { create(:question_group, session: session) }
  let(:user_session) do
    create(:user_session, user: user, session: session, user_intervention: user_intervention,
                          health_clinic: health_clinic, finished_at: DateTime.now)
  end

  def question(name, group: question_group)
    create(:question_number, question_group: group, body: { data: [{ payload: '' }], variable: { name: name } })
  end

  def answer!(question, value, fill: user_session)
    create(:answer_number, user_session: fill, question: question, body: { data: [{ var: question.body['variable']['name'], value: value }] })
  end

  # A skip stores a CONFIRMED answer whose body entry has a blank `var`. The variable never
  # reaches var values, so it lands in `missing_vars` - but the question was reached.
  def skip!(question, fill: user_session)
    create(:answer_number, user_session: fill, question: question, skipped: true, body: { data: [{ var: '', value: '' }] })
  end

  describe '.none_answered?' do
    subject { described_class.none_answered?(user_session, missing_vars) }

    let!(:q1) { question('q1') }
    let!(:q2) { question('q2') }
    let(:missing_vars) { ['ht1.q1', 'ht1.q2'] }

    context 'when no owning question has any confirmed answer' do
      it 'is true - the participant never reached the instrument' do
        expect(subject).to be true
      end
    end

    context 'when one of the owning questions was answered' do
      before { answer!(q1, '5') }

      it 'is false - the participant reached the instrument' do
        expect(subject).to be false
      end
    end

    context 'when the owning questions were reached and SKIPPED' do
      # THE load-bearing case. `Answer.confirmed` is `where(draft: false)` only, so a skip
      # leaves a confirmed row; measuring "answered" on var-values presence instead would
      # report this participant as absent and newly drop them, and they are charted today.
      before do
        skip!(q1)
        skip!(q2)
      end

      it 'is false - a skip proves the question was reached' do
        expect(subject).to be false
      end
    end

    context 'when the only answer is a DRAFT' do
      before { create(:answer_number, user_session: user_session, question: q1, draft: true, body: { data: [{ var: 'q1', value: '5' }] }) }

      it 'is true - a draft answer is not a confirmed one' do
        expect(subject).to be true
      end
    end

    context 'when the answer belongs to a question the formula does not reference' do
      let!(:unrelated) { question('terms') }

      before { answer!(unrelated, '1') }

      it 'is true - answering something else is not reaching this instrument' do
        expect(subject).to be true
      end
    end

    context 'when missing_vars is empty' do
      let(:missing_vars) { [] }

      it 'is false - there is nothing to measure' do
        expect(subject).to be false
      end
    end

    context 'when no question in the intervention owns any missing variable' do
      # `owning_question_ids.empty?` bails out DELIBERATELY: with nothing to attribute the
      # variables to, this class must not claim the participant is absent. It is also the
      # residual cross-intervention hole (a chart formula naming variables that live only in
      # another intervention of the same organization), which `CreateForUserSession`'s
      # session pre-filter closes from the other side.
      let(:missing_vars) { ['ht1.not_in_this_intervention'] }

      it 'is false - the deliberate owning_question_ids.empty? bail-out' do
        expect(subject).to be false
      end
    end

    describe 'qualified-pair vs bare-name attribution' do
      # Copying a session renames the SESSION variable (`clone_jobs/session.rb:15`) but never
      # the question variables inside it, so one intervention legitimately holds two questions
      # named `q2`.
      let(:copied_session) { create(:session, intervention: intervention, variable: 'ht1_copy') }
      let(:copied_group) { create(:question_group, session: copied_session) }
      let!(:copied_q2) { question('q2', group: copied_group) }

      context 'when the missing variable is qualified with a session the twin does not belong to' do
        let(:missing_vars) { ['ht1.q2'] }

        before { skip!(q2) }

        it 'attributes it to the question in that session only' do
          expect(subject).to be false
        end
      end

      context 'when the missing variable is qualified with the COPIED session' do
        let(:missing_vars) { ['ht1_copy.q2'] }

        # `skip!(q2)` is what makes this example a FALSIFIER rather than a tautology. Under
        # pair matching the owning set is `[copied_q2]` and nothing answered it, so the
        # result is true. Regress to bare-name-everywhere and the owning set becomes
        # `[q2, copied_q2]` with `q2` answered, so `answered_question_ids` is non-empty and
        # the result flips to false. Without the skip both regimes return true and the
        # example cannot fail (review round 1, F3).
        before { skip!(q2) }

        it 'attributes it to the twin, which the participant never opened' do
          expect(subject).to be true
        end
      end

      context 'when the missing variable is BARE' do
        # Nothing better to attribute an unqualified variable to, so it keeps the
        # pre-existing intervention-wide match by name - both `q2` questions own it.
        let(:missing_vars) { ['q2'] }

        before { skip!(q2) }

        it 'matches every same-named question in the intervention' do
          expect(subject).to be false
        end
      end
    end

    describe 'latest_user_sessions scoping across a multiple-fill retake' do
      # `latest_user_sessions` is `DISTINCT ON (session_id) ... ORDER BY session_id,
      # created_at DESC, id DESC`, so only the NEWEST fill of each session contributes. The
      # implementation must use `.map(&:id)`, never `.pluck(:id)` - `pluck` replaces
      # `select_values` and destroys the `DISTINCT ON`, which would let the older fill's
      # answers count as well.
      let(:sibling_clinic) { create(:health_clinic, health_system: health_system) }
      let(:session) { create(:session, intervention: intervention, variable: 'ht1', multiple_fill: true) }

      let(:user_session) do
        create(:user_session, user: user, session: session, user_intervention: user_intervention, multiple_fill: true,
                              health_clinic: health_clinic, finished_at: DateTime.now - 2.hours, created_at: DateTime.now - 3.hours)
      end
      let(:retake) do
        create(:user_session, user: user, session: session, user_intervention: user_intervention, multiple_fill: true,
                              health_clinic: sibling_clinic, finished_at: DateTime.now - 1.hour, created_at: DateTime.now - 1.hour)
      end

      context 'when only the OLDER fill answered the owning questions' do
        before do
          answer!(q1, '5')
          retake
        end

        it 'is true - the older fill is not in latest_user_sessions' do
          expect(subject).to be true
        end
      end

      context 'when the NEWER fill answered an owning question' do
        before do
          answer!(q1, '5')
          answer!(q1, '7', fill: retake)
        end

        it 'is false - the newest fill is the one that counts' do
          expect(subject).to be false
        end
      end
    end
  end
end
