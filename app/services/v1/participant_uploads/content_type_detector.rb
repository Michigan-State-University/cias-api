# frozen_string_literal: true

class V1::ParticipantUploads::ContentTypeDetector
  UNKNOWN = 'application/octet-stream'
  TEXTUAL = 'text/plain'
  OLE = 'application/x-ole-storage'
  CONTROL_BYTES = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/

  OLE_STREAMS = {
    'WordDocument' => 'application/msword',
    'Workbook' => 'application/vnd.ms-excel',
    'Book' => 'application/vnd.ms-excel'
  }.freeze

  DIRECTORY_ENTRY_SIZE = 128
  SECTOR_SHIFT_OFFSET = 0x1E
  FIRST_DIRECTORY_SECTOR_OFFSET = 0x30
  STREAM_ENTRY_TYPE = 2
  DIRECTORY_SCAN_BYTES = 1.megabyte
  TEXTUAL_CHUNK_BYTES = 64.kilobytes
  TEXTUAL_SCAN_BYTES = 1.megabyte

  def self.call(io) = new(io).call

  def initialize(io)
    @io = io
  end

  def call
    detected = Marcel::MimeType.for(@io)
    return ole_subtype if detected == OLE
    return detected unless detected == UNKNOWN

    textual? ? TEXTUAL : UNKNOWN
  end

  private

  def ole_subtype
    directory_bytes.to_s.bytes.each_slice(DIRECTORY_ENTRY_SIZE) do |entry|
      content_type = OLE_STREAMS[entry_name(entry.pack('C*'))]
      return content_type if content_type
    end

    OLE
  end

  def entry_name(entry)
    return nil if entry.bytesize < DIRECTORY_ENTRY_SIZE
    return nil unless entry.getbyte(66) == STREAM_ENTRY_TYPE

    name_length = entry[64, 2].unpack1('v').to_i
    return nil unless name_length.between?(4, 64)

    entry[0, name_length - 2].force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8)
  rescue EncodingError
    nil
  end

  def directory_bytes
    header = read_at(0, 512)
    return nil if header.nil? || header.bytesize < 512

    sector_size = 1 << header[SECTOR_SHIFT_OFFSET, 2].unpack1('v').to_i
    return nil unless sector_size.between?(64, 4096)

    first_sector = header[FIRST_DIRECTORY_SECTOR_OFFSET, 4].unpack1('V').to_i
    read_at((first_sector + 1) * sector_size, DIRECTORY_SCAN_BYTES)
  end

  def read_at(offset, length)
    @io.seek(offset)
    @io.read(length)&.b
  rescue IOError, SystemCallError
    nil
  end

  def textual?
    @io.seek(0)
    buffer = +''
    carry = +''
    scanned = 0

    while scanned < TEXTUAL_SCAN_BYTES && @io.read(TEXTUAL_CHUNK_BYTES, buffer)
      scanned += buffer.bytesize
      carry = text_chunk_tail(carry.empty? ? buffer : carry + buffer)
      return false if carry.nil?
    end

    scanned.positive? && (carry.empty? || scanned >= TEXTUAL_SCAN_BYTES)
  rescue IOError, SystemCallError
    false
  end

  def text_chunk_tail(block)
    tail = +''

    unless utf8?(block)
      tail = unfinished_character(block)
      return nil if tail.nil?

      block = block.byteslice(0, block.bytesize - tail.bytesize)
    end

    control_bytes?(block) ? nil : tail
  end

  def unfinished_character(block)
    (1..3).each do |length|
      break if length >= block.bytesize

      return block.byteslice(-length, length) if utf8?(block.byteslice(0, block.bytesize - length))
    end

    nil
  end

  def utf8?(bytes)
    bytes.force_encoding(Encoding::UTF_8).valid_encoding?
  ensure
    bytes.force_encoding(Encoding::BINARY)
  end

  def control_bytes?(bytes)
    bytes.force_encoding(Encoding::UTF_8).match?(CONTROL_BYTES)
  ensure
    bytes.force_encoding(Encoding::BINARY)
  end
end
