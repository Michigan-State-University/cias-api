# frozen_string_literal: true

RSpec.describe V1::SmsPlans::CalculateMatchedVariant do
  subject { described_class.call(formula, variants, all_var_answer_values) }

  let!(:user) { create(:user) }

  context 'when there are no formula variables in the answers variables' do
    let!(:formula) { 'sport_var' }
    let!(:sms_plan) { create(:sms_plan, formula: formula, is_used_formula: true) }
    let!(:variant) { create(:sms_plan_variant, formula_match: '=2', sms_plan: sms_plan) }
    let!(:variants) { sms_plan.variants }
    let!(:all_var_answer_values) { { 'no_yes_var' => 1 } }

    it 'returns nil' do
      expect(subject).to eq nil
    end
  end

  context 'when there are formula variables in the answers variables' do
    let!(:formula) { 'sport_var' }
    let!(:sms_plan) { create(:sms_plan, formula: formula, is_used_formula: true) }
    let!(:variant) { create(:sms_plan_variant, formula_match: '=2', sms_plan: sms_plan) }
    let!(:variants) { sms_plan.variants }
    let!(:all_var_answer_values) { { 'sport_var' => 2 } }

    it 'returns variant' do
      expect(subject).to eq variant
    end
  end
end
