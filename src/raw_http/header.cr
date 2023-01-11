module RawHttp
  # TODO: case insensitivity
  class Header
    def initialize(lines : Array(String))
      @lines = lines
    end

    def self.read(sock)
      lines = [] of String
      while (raw_line = sock.gets)
        # HACK: Not sure what the performance implications of including this here is.  Trying
        # to identify the source of pauses/quick hangs in the UI.
        # Fiber.yield
        line = raw_line.strip
        break if line.bytesize == 0
        lines << line
      end
      return Header.new lines
    end

    def clone
      Header.new @lines.clone
    end

    def value(name)
      @lines.each do |line|
        if line.starts_with?(name + ": ")
          return line[name.bytesize + 2..-1]
        end
      end
      return nil
    end

    def add(name, value)
      @lines << "#{name}: #{value}"
    end

    def host
      self.value("Host").not_nil!
    end

    def remove(name : String)
      @lines.each_with_index do |line, index|
        # for line in @lines
        if line.starts_with?(name + ": ")
          @lines.delete_at(index)
        end
      end
    end

    def update(name : String, value : String)
      remove(name)
      add(name, value)
    end

    def path
      @lines[0].split[1]
    end

    def url
      path = self.path
      if path[0] != "/"
        return self.path
      else
        return self.host + self.path
      end
    end

    def method
      @lines[0].split[0]
    end

    def status
      @lines[0].split[1]
    end

    def write(sock)
      @lines.each do |line|
        # Fiber.yield
        sock.write((line + "\r\n").to_slice)
      end
      sock.write("\r\n".to_slice)
    end

    def to_s(io)
      @lines.each do |line|
        io << line
        io << "\r\n"
      end
      io << "\r\n"
    end

    getter :lines
  end
end
