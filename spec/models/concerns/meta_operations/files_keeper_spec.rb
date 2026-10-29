# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetaOperations::FilesKeeper, type: :model do
  subject(:keeper) { described_class.new(stream: '%PDF-1.4 participant A', add_to: report, **shared_options) }

  let(:shared_options) { { filename: 'report', macro: :pdf_report, ext: :pdf, type: 'application/pdf' } }
  let(:report) { create(:generated_report) }
  let(:other_report) { create(:generated_report) }
  let(:other_keeper) { described_class.new(stream: '%PDF-1.4 participant B', add_to: other_report, **shared_options) }

  after do
    [keeper, other_keeper].each do |instance|
      instance.send(:delete_tmp_file) if instance.instance_variable_defined?(:@tmp_file)
    end
  end

  it 'uses a separate tmp path for every instance sharing a filename' do
    expect(keeper.send(:tmp_file)).not_to eq(other_keeper.send(:tmp_file))
  end

  it 'does not let a concurrent file with the same name replace the content being attached' do
    keeper.send(:tmp_file)
    other_keeper.send(:tmp_file)
    GeneratedReport.transaction { keeper.send(:attach_tmp_file) }

    expect(report.reload.pdf_report.download).to eq('%PDF-1.4 participant A')
  end

  it 'attaches the file under the name free of the tmp path prefix' do
    keeper.execute

    expect(report.reload.pdf_report.filename.to_s).to eq('report.pdf')
  end
end
