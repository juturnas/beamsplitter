require "http/client"
require "mime/multipart"

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
    boundary = MIME::Multipart.generate_boundary

    headers = HTTP::Headers{
      "X-Beamsplitter-Session-Id" => @session_id,
      "Content-Type"              => "multipart/mixed; boundary=" + boundary,
      "User-Agent"                => "Beamsplitter",
    }

    body = MIME::Multipart.build(boundary) do |builder|
      builder.body_part HTTP::Headers{"Content-Type"        => "application/octet-stream",
                                      "Content-Disposition" => "attachment; name=\"request\"",
      }, roundtrip.request.to_s

      builder.body_part HTTP::Headers{"Content-Type"        => "application/octet-stream",
                                      "Content-Disposition" => "attachment; name=\"response\"",
      }, roundtrip.response.to_s
    end

    HTTP::Client.post(@url, headers: headers, body: body)
  end
end
