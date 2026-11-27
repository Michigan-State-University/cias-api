# frozen_string_literal: true

class V1::ParticipantUploads::BlobRangeIo
  WINDOW_BYTES = 256.kilobytes

  def initialize(blob)
    @blob = blob
    @position = 0
    @window_start = nil
    @window_bytes = +''
  end

  def size
    @blob.byte_size
  end

  def rewind
    @position = 0
  end

  def seek(offset)
    @position = offset
    0
  end

  def read(length = nil, buffer = nil)
    bytes = fetch(length.nil? ? size - @position : length)
    @position += bytes.bytesize

    if bytes.empty?
      buffer&.clear
      return nil
    end

    buffer.nil? ? bytes : buffer.replace(bytes)
  end

  private

  def fetch(length)
    return +'' if length <= 0 || @position >= size

    stop = [@position + length, size].min
    load_window(@position, stop)
    @window_bytes.byteslice(@position - @window_start, stop - @position)
  end

  def load_window(from, to)
    return if covered?(from, to)

    stop = (from + WINDOW_BYTES).clamp(to, size)
    @window_start = from
    @window_bytes = @blob.service.download_chunk(@blob.key, from...stop).b
  end

  def covered?(from, to)
    @window_start && from >= @window_start && to <= @window_start + @window_bytes.bytesize
  end
end
