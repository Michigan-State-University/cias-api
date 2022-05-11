# frozen_string_literal: true

RSpec.describe V1::ReorderService do
  context 'sms plan variants' do
    subject { described_class.call(sms_plan.variants, params) }

    let(:user) { create(:user, :admin, :confirmed) }
    let(:intervention) { create(:intervention, user: user) }
    let(:session) { create(:session, intervention: intervention) }
    let(:sms_plan) { create(:sms_plan, session: session) }
    let!(:sms_variants) { create_list(:sms_plan_variant, 5, sms_plan: sms_plan) }

    let(:params) do
      [
        {
          'id' => sms_variants[0].id, 'position' => 2
        },
        {
          'id' => sms_variants[2].id, 'position' => 0
        },
        {
          'id' => sms_variants[1].id, 'position' => 3
        },
        {
          'id' => sms_variants[3].id, 'position' => 1
        }
      ]
    end

    context 'when all params valid it performs reorder correctly' do
      it do
        subject
        expect(sms_variants.map(&:reload).pluck(:position)).to eq [2, 3, 0, 1, sms_variants[4].position]
      end
    end

    context 'when invalid params it fails gracefully' do
      let(:params) do
        [
          {
            'id' => 'invalid-id', 'position' => 1
          },
          {
            'id' => 'invalid-id-2', 'position' => 2
          }
        ]
      end

      it do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  context 'report template sections' do
    subject { described_class.call(report_template.sections, params) }

    let!(:current_v1_user) { create(:user, :confirmed, :admin) }
    let!(:session) { create(:session) }
    let!(:report_template) { create(:report_template, session: session) }
    let!(:section1) do
      create(:report_template_section, report_template: report_template, position: 0)
    end
    let!(:section2) do
      create(:report_template_section, report_template: report_template, position: 1)
    end
    let!(:section3) do
      create(:report_template_section, report_template: report_template, position: 2)
    end
    let!(:params) do
      [
        { 'id' => section2.id, 'position' => 2 },
        { 'id' => section3.id, 'position' => 1 }
      ]
    end

    context 'when all params are valid service should change position indicated sections' do
      it 'update correct sections' do
        subject
        expect(section2.reload.position).to be 2
        expect(section3.reload.position).to be 1
      end
    end

    context 'when some of the params are invalid it will be raise exception' do
      let!(:params) do
        [
          { 'id' => 'wrong_id', 'position' => 2 },
          { 'id' => section3.id, 'position' => 1 }
        ]
      end

      it 'raise NotFoundException and all operation will be rollback' do
        expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
        expect(section3.reload.position).to be 2
      end

      context 'when report template id is wrong' do
        let!(:report_template_id) { 'wrong_id' }

        it 'raise correct exception' do
          expect { subject }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
