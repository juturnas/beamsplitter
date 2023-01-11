require "http/client"

require "./proxy"

class Application
  def initialize(@port : Int32, @url : String, @session_id : String)
    @proxy = Proxy.new(@port, nil)
  end

  def shutdown
  end

  def run
    spawn { @proxy.run }

    loop do
      msg = @proxy.queue.receive
      spawn report(msg)
    end
  end

  def report(roundtrip)
    req_bytes = roundtrip.request.to_s
    res_bytes = roundtrip.response.to_s
    headers = HTTP::Headers{
      "X-Beamsplitter-Request-Length" => req_bytes.bytesize.to_s,
      "X-Beamsplitter-Session-Id"     => @session_id,
    }
    body = req_bytes + res_bytes
    HTTP::Client.post(@url, headers: headers, body: body)
  end
end
