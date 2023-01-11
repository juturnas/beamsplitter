module RawHttp
  # TODO: Is there a more idiomatic way to do this?
  class Roundtrip
    def initialize(@request : Message, @response : Message)
    end

    getter :request, :response
  end
end
