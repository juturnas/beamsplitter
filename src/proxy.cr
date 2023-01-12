require "socket"
require "openssl"

require "raw_http"
require "./insecure_certs"

# TODO: Add shutdown functionality
# TODO: Websockets
class Proxy
  getter :queue

  @request_transformer : Nil | (RawHTTP::Message -> RawHTTP::Message)

  def initialize(@port : Int32, @request_transformer = nil)
    @queue = Channel(RawHTTP::Roundtrip).new(128)
    @listener = TCPServer.new(@port)
    @client_ctx = OpenSSL::SSL::Context::Client.new
    @server_ctx = OpenSSL::SSL::Context::Server.new

    cert_path, key_path = InsecureCertificates.write_to_temp_files
    @server_ctx.private_key = key_path
    @server_ctx.certificate_chain = cert_path
  end

  # Applies @request_transformer if one has been provided
  def transform_request(request)
    @request_transformer ? @request_transformer.not_nil!.call(request) : request
  end

  def handle_direct(client, request_header)
    request_body = RawHTTP::Body.read_for_header(client, request_header)
    request = RawHTTP::Message.new(request_header, request_body)
    request = transform_request request
    TCPSocket.open(request.header.host, 80) { |remote|
      request.write(remote)
      response = RawHTTP::Message.read(remote)
      response.write(client)
      @queue.send(RawHTTP::Roundtrip.new(request, response))
    }
  end

  def ssl(host, port)
    TCPSocket.open(host, port) { |sock|
      secure_sock = OpenSSL::SSL::Socket::Client.new(sock, @client_ctx, true, host)
      begin
        yield secure_sock
      ensure
        secure_sock.flush
        secure_sock.close
      end
    }
  end

  def handle_tunnel(client, tunnel_request)
    client.write("HTTP/1.1 200 OK\r\n\r\n".to_slice)
    client_secure = OpenSSL::SSL::Socket::Server.new(client, @server_ctx)
    begin
      host = tunnel_request.value("Host").not_nil!.split ":"
      self.ssl(host[0], host[1].to_i) { |remote|
        request = RawHTTP::Message.read(client_secure)
        request = transform_request request
        request.write(remote)
        remote.flush
        response = RawHTTP::Message.read(remote)
        response.write(client_secure)
        @queue.send(RawHTTP::Roundtrip.new(request, response))
      }
    ensure
      client_secure.flush
      client_secure.close
    end
  end

  def handle_client(client)
    request_header = RawHTTP::Header.read(client)
    if request_header.method == "CONNECT"
      self.handle_tunnel(client, request_header)
    else
      self.handle_direct(client, request_header)
    end
  end

  def run
    loop do
      Fiber.yield
      client = @listener.accept
      spawn {
        begin
          self.handle_client client
        rescue
          # TODO: How best to report/surface errors?
        ensure
          client.flush
          client.close
        end
      }
    end
  end
end
