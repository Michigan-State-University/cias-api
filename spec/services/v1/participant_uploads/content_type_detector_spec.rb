# frozen_string_literal: true

RSpec.describe V1::ParticipantUploads::ContentTypeDetector do
  def detect(bytes)
    described_class.call(StringIO.new(bytes))
  end

  def fixture_bytes(name)
    Rails.root.join('spec/fixtures/participant_uploads', name).binread
  end

  describe 'binary signatures win over the file name' do
    it 'detects a PNG' do
      expect(detect("\x89PNG\r\n\x1a\n".b + ("\x00" * 64))).to eq('image/png')
    end

    it 'detects a PDF' do
      expect(detect("%PDF-1.4\n".b + ("\x00" * 64))).to eq('application/pdf')
    end

    it 'detects an executable' do
      expect(detect("MZ\x90\x00".b + ("\x00" * 64))).to eq('application/x-msdownload')
    end

    it 'detects a HEIC image' do
      expect(detect("\x00\x00\x00\x18ftypheic".b + ("\x00" * 64))).to eq('image/heic')
    end

    # Synthetic ftyp bytes proved only that the branch exists. This one an encoder wrote,
    # and the ticket puts heic on the allowlist.
    it 'detects an encoded HEIC, and the allowlist accepts it' do
      detected = detect(fixture_bytes('encoded_sample.heic'))

      expect(detected).to eq('image/heic')
      expect(Settings.participant_uploads.allowed_content_types).to include(detected)
    end
  end

  describe 'the text test walks the whole file in chunks' do
    it 'types a text file many chunks long' do
      expect(detect('a' * (described_class::TEXTUAL_CHUNK_BYTES * 3))).to eq('text/plain')
    end

    it 'still calls binary content binary' do
      expect(detect("\x00\x01\x02".b * described_class::TEXTUAL_CHUNK_BYTES)).to eq('application/octet-stream')
    end

    it 'does not mistake a multi-byte character cut by a chunk boundary for binary' do
      padding = 'a' * (described_class::TEXTUAL_CHUNK_BYTES - 1)

      expect(detect("#{padding}ł#{'a' * 100}")).to eq('text/plain')
    end

    it 'refuses a text prefix with a binary tail' do
      head = 'a' * (described_class::TEXTUAL_CHUNK_BYTES * 2)

      expect(detect(head + ("\x00\x01\x02".b * 100))).to eq('application/octet-stream')
    end

    it 'refuses a trailing broken character rather than trimming it away' do
      expect(detect("abc\xFF".b)).to eq('application/octet-stream')
    end

    it 'refuses an empty file' do
      expect(detect('')).to eq('application/octet-stream')
    end
  end

  describe 'containers' do
    it 'detects a real docx by its content' do
      expect(detect(fixture_bytes('sample.docx'))).to eq(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      )
    end

    it 'detects a real xlsx by its content' do
      expect(detect(fixture_bytes('sample.xlsx'))).to eq(
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )
    end

    it 'refuses to pass a plain ZIP off as a docx' do
      expect(detect(fixture_bytes('plain.zip'))).to eq('application/zip')
    end

    it 'refuses to name an OLE container that holds neither Word nor Excel' do
      expect(detect(fixture_bytes('sample.ole'))).to eq('application/x-ole-storage')
      expect(Settings.participant_uploads.allowed_content_types).not_to include('application/x-ole-storage')
    end

    it 'is not fooled by the word Workbook sitting in the payload' do
      expect(detect(fixture_bytes('sample_decoy.ole'))).to eq('application/x-ole-storage')
    end

    it 'detects a legacy doc by its stream name' do
      expect(detect(fixture_bytes('sample_word.ole'))).to eq('application/msword')
    end

    it 'detects a legacy xls by its stream name' do
      expect(detect(fixture_bytes('sample_excel.ole'))).to eq('application/vnd.ms-excel')
    end

    # Written by macOS `textutil -convert doc`, not by our own OLE writer: the other
    # fixtures only prove the parser reads back what the same script laid down.
    it 'detects a doc written by a real word processor' do
      expect(detect(fixture_bytes('real_sample.doc'))).to eq('application/msword')
    end

    # A genuine BIFF workbook (ruby-ole). Marcel already types this one from its
    # signature, so it never reaches the directory parser — it proves the allowlist
    # accepts a real xls, not that the parser handles one.
    it 'accepts a workbook written by a real spreadsheet writer' do
      expect(detect(fixture_bytes('real_sample.xls'))).to eq('application/vnd.ms-excel')
    end
  end

  describe 'textual content' do
    it 'detects plain text' do
      expect(detect("ala ma kota\nbez kota\n".b)).to eq('text/plain')
    end

    it 'detects CSV content as text' do
      expect(detect("a,b,c\n1,2,3\n".b)).to eq('text/plain')
    end

    it 'does not call arbitrary binary content text' do
      expect(detect("\x00\x01\x02\x03\x7f\x05".b)).to eq('application/octet-stream')
    end

    it 'does not call invalid UTF-8 text' do
      expect(detect("\xC3\x28\xA0\xA1".b)).to eq('application/octet-stream')
    end
  end

  describe 'reading the bytes straight from the storage, in ranges' do
    def detect_blob(bytes, filename)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(bytes), filename: filename, content_type: 'application/octet-stream', identify: false
      )
      described_class.call(V1::ParticipantUploads::BlobRangeIo.new(blob))
    end

    it 'subtypes a legacy Word file whose directory sits past the first sector' do
      expect(detect_blob(fixture_bytes('real_sample.doc'), 'upload.doc')).to eq('application/msword')
    end

    it 'subtypes a legacy Excel file' do
      expect(detect_blob(fixture_bytes('real_sample.xls'), 'upload.xls')).to eq('application/vnd.ms-excel')
    end

    it 'still refuses an OLE container that holds neither' do
      expect(detect_blob(fixture_bytes('sample_decoy.ole'), 'upload.doc')).to eq('application/x-ole-storage')
    end

    it 'reads a real docx' do
      expect(detect_blob(fixture_bytes('sample.docx'), 'upload.docx'))
        .to eq('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    end

    it 'calls a text file longer than the scan budget text, without reading all of it' do
      bytes = ('zażółć gęślą jaźń ' * 200_000).b

      expect(bytes.bytesize).to be > V1::ParticipantUploads::ContentTypeDetector::TEXTUAL_SCAN_BYTES
      expect(detect_blob(bytes, 'upload.txt')).to eq('text/plain')
    end

    it 'still refuses a file that only starts as text' do
      bytes = ('a' * 1.kilobyte).b + ("\x00\x01\x02".b * 100)

      expect(detect_blob(bytes, 'upload.txt')).to eq('application/octet-stream')
    end

    def ole_with_directory_at(offset, stream_name)
      sector = 512
      header = (+"\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1").b + ("\x00".b * (sector - 8))
      header.setbyte(0x1E, 9)
      header.setbyte(0x1F, 0)
      header[0x30, 4] = [(offset / sector) - 1].pack('V')
      name = stream_name.encode(Encoding::UTF_16LE).b
      entry = (+"\x00".b * 128)
      entry[0, name.bytesize] = name
      entry[64, 2] = [name.bytesize + 2].pack('v')
      entry.setbyte(66, 2)
      header + ("\x00".b * (offset - sector)) + entry + ("\x00".b * sector)
    end

    it 'subtypes a legacy Word file whose directory sits past the first megabyte' do
      bytes = ole_with_directory_at(3.megabytes, 'WordDocument')

      expect(bytes.bytesize).to be > described_class::DIRECTORY_SCAN_BYTES
      expect(detect_blob(bytes, 'upload.doc')).to eq('application/msword')
    end

    it 'types a file without reading it one magic rule at a time' do
      bytes = Rails.root.join('spec/fixtures/participant_uploads/real_sample.doc').binread
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(bytes), filename: 'upload.doc', content_type: 'application/octet-stream', identify: false
      )
      chunks = 0
      subscription = ActiveSupport::Notifications.subscribe('service_download_chunk.active_storage') { chunks += 1 }
      described_class.call(V1::ParticipantUploads::BlobRangeIo.new(blob))
      ActiveSupport::Notifications.unsubscribe(subscription)

      expect(chunks).to be <= 8
    end

    it 'reports the end of the file instead of looping' do
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('abc'), filename: 'upload.txt', content_type: 'text/plain', identify: false
      )
      io = V1::ParticipantUploads::BlobRangeIo.new(blob)

      expect(io.read(3)).to eq('abc')
      expect(io.read(3)).to be_nil
      io.seek(1)
      expect(io.read(1)).to eq('b')
    end
  end
end
