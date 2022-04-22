# frozen_string_literal: true

RSpec.describe V1::ReportTemplates::SectionReorderService do
  subject { described_class.call(report_template_id, params) }

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
  let!(:report_template_id) { report_template.id }
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
