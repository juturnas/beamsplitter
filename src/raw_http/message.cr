module RawHttp
  class Message
    def initialize(header : Header, body : (Nil | Body))
      @header = header
      @body = body
    end

    def self.read(sock)
      header = Header.read(sock)
      body = Body.read_for_header(sock, header)

      return Message.new(header, body)
    end

    def write(sock)
      @header.write(sock)
      if @body
        @body.not_nil!.write(sock)
      end
    end

    def roundtrip(sock)
      self.write(sock)
      return Message.read(sock)
    end

    def to_s(io)
      io << @header << @body
    end

    def decoded(io)
      io << @header << @body.decoded(@header.value("Content-Encoding"))
    end

    def status
      @header.status
    end

    def decoded
      builder = String::Builder.new
      builder << @header
      if body = @body
        builder << body.decoded(@header.value("Content-Encoding"))
      end
      builder.to_s
    end

    # TODO: HACK Fix this
    def update_content_length
      if body = @body
        case body.body
        when String
          @header.update("Content-Length", body.body.as(String).size.to_s)
        when Array(String)
          raise "TODO: Figure out how best to handle fuzzing chunked messages"
        end
      else
        @header.remove("Content-Length")
      end
    end

    getter :header, :body
  end
end
