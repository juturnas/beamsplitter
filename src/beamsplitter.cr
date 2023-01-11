require "option_parser"
require "./application"

# Command line options
port : Int32 = 8085
url : String = ""
session_id : String = Random.new.base64

begin
  OptionParser.parse do |parser|
    parser.banner = "Usage: beamsplitter [-p <port>] [-i <session-id>] -u <url>"
    parser.on("-p", "--port=PORT", "Local port to listen for HTTP/S trafic on") { |p|
      port = p.to_i32
    }
    parser.on("-u", "--url=URL", "The URL to forward HTTP/S traffic to") { |u|
      url = u
    }

    parser.on("-i", "--session-id=ID", "A session ID reported via the X-Beamsplitter-Session-Id header") { |id|
      session_id = id
    }

    if url.size == 0
      puts parser
      exit
    end
  end
rescue err
  puts err
  exit
end

app = Application.new(port, url, session_id)

at_exit do
  app.shutdown
end

app.run
