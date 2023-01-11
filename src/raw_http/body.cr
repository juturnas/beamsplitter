module RawHttp
  class Body
    def initialize(body : (String | Array(String)))
      @body = body
    end

    getter body

    def self.read_chunk(sock)
      if size_line = sock.gets
        size = size_line.strip.to_i(16)
        chunk = sock.read_string(size)
        sock.read_string(2)
        return chunk
      end
    end

    def self.write_chunk(sock, chunk)
      sock.write((chunk.bytesize.to_s(16) + "\r\n").to_slice)
      sock.write(chunk.to_slice)
      sock.write("\r\n".to_slice)
    end

    def self.read_for_header(sock, header)
      if length_str = header.value("Content-Length")
        if length = length_str.to_i
          return Body.new sock.read_string(length)
        end
      end
      if transfer_encoding = header.value("Transfer-Encoding")
        chunks = [] of String
        while (chunk = Body.read_chunk(sock))
          break if chunk.bytesize == 0
          chunks << chunk
        end
        return Body.new chunks
      end
      return nil
    end

    # Encoded representation
    def write(sock)
      case @body
      when String
        sock.write(@body.as(String).to_slice)
      when Array
        @body.as(Array(String)).each do |chunk|
          Body.write_chunk(sock, chunk)
        end
        sock.write("0\r\n\r\n".to_slice)
      end
    end

    # Decoded representation
    def to_s(io)
      case @body
      when String
        io << @body
      when Array
        @body.as(Array(String)).each do |chunk|
          io << chunk
        end
      end
    end

    def to_s
      builder = String::Builder.new
      self.to_s(builder)
      builder.to_s
    end

    def decoded(content_encoding)
      case content_encoding
      when "gzip"
        begin
          io = IO::Memory.new(self.to_s)
          Gzip::Reader.open(io, sync_close: true) do |gzip|
            gzip.gets_to_end
          end
        rescue
          self.to_s
        end
      else
        self.to_s
      end
    end
  end
end
