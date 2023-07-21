# frozen_string_literal: true

require 'rails_helper'

describe Api::Documo::SendFax do
  subject { described_class.new(fax_number, logo_url, pdf_file_url) }

  let!(:fax_number) { '12025550100' }
  let!(:logo_url) { 'https://picsum.photos/400' }

  context 'when sending a request to print a single page pdf with a logo' do
    let!(:pdf_file_url) { 'https://www.soundczech.cz/temp/lorem-ipsum.pdf' }

    it 'asks the API to print 2 pages' do
      expect(subject.call['pagesCount']).to eq(2)
    end
  end
end
