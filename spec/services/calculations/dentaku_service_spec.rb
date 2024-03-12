# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Calculations::DentakuService do
  subject do
    described_class.new(
      all_var_values, formula, nil, other_data
    )
  end

  let(:dentaku_calculator) { Dentaku::Calculator.new }
  let(:all_var_values) { { var1: 5, var2: 5, var3: 10, var4: 5 } }
  let(:formula) { 'var1-var2' }
  let!(:user) { create(:user) }
  let(:other_data) do
    {
      is_formula_interface: false,
      user_id: user.id
    }
  end

  before do
    allow(Dentaku::Calculator).to receive(:new).and_return(dentaku_calculator)
  end

  describe '#store_and_transform_values' do
    let(:call) { subject.store_and_transform_values }

    it 'changes dentaku calculator memory' do
      expect do
        call
      end.to change(dentaku_calculator, :memory).from({}).to({ 'var1' => 5, 'var2' => 5, 'var3' => 10, 'var4' => 5 })
    end

    context 'all_var_values are empty' do
      let(:all_var_values) {}

      it 'does not change dentaku calculator memory' do
        expect { call }.not_to change(dentaku_calculator, :memory)
      end
    end
  end

  describe '#evaluate' do
    let!(:variant1) { create(:report_template_section_variant, formula_match: '=10') }
    let!(:variant2) { create(:report_template_section_variant, formula_match: '<10') }
    let(:variants) { ReportTemplate::Section::Variant.all }
    let(:call) { subject.evaluate(formula, variants) }

    context 'formula contains variables from previous session' do
      let(:all_var_values) { { 's1234.var1' => 5, 's1235.var2' => 5 } }
      let(:formula) { 's1234.var1+s1235.var2' }

      it 'return proper variant' do
        subject.store_and_transform_values
        expect(call).to eq(variant1)
      end
    end

    it 'returns proper variant' do
      expect(call).to eq(variant2)
    end

    it 'changes dentaku calculator memory' do
      expect { call }.to change(dentaku_calculator, :memory).from({}).to({ 'var1' => 0, 'var2' => 0 })
    end

    context 'formula covers existing vars' do
      before do
        subject.store_and_transform_values
      end

      it 'does not change dentaku calculator memory' do
        expect { call }.not_to change(dentaku_calculator, :memory)
      end
    end

    context 'formula is empty' do
      let(:formula) {}

      it 'throws proper error' do
        expect(call).to be_nil
      end

      it 'does not change dentaku calculator memory' do
        expect { call }.not_to change(dentaku_calculator, :memory)
      end
    end

    context 'variables are empty' do
      let(:variants) {}

      it 'throws proper error' do
        expect { call }.to raise_error(NoMethodError, 'undefined method `order\' for nil:NilClass')
      end
    end
  end
end
