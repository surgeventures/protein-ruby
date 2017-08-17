require "net/http"
require "json"

module Surgery
module RPC
class HTTPAdapter
  class Middleware
    class << self
      def mount(router, processor_class)
        transport_class = processor_class.transport_class
        path = transport_class.path
        middleware = new(processor_class)

        router.post(path => Proc.new { |env| middleware.call(env) })
      end
    end

    def initialize(processor_class)
      @processor_class = processor_class
      @transport_class = processor_class.transport_class
    end

    def call(env)
      check_secret(env)

      request_params = decode_params(env)
      service_name = request_params["service_name"]
      request_buf_b64 = request_params["request_buf_b64"]
      request_buf = Base64.strict_decode64(request_buf_b64)

      response_buf, errors = @processor_class.call(service_name, request_buf)

      response_headers = build_response_headers
      response_body = build_response_body(response_buf, errors)

      ["200", response_headers, [response_body]]
    end

    private

    def check_secret(env)
      return if @transport_class.secret == env["HTTP_X_RPC_SECRET"]

      raise(TransportError, "invalid secret")
    end

    def decode_params(env)
      request_body = env["rack.input"].read

      JSON.parse(request_body)
    end

    def build_response_headers
      { "Content-Type" => "application/json" }
    end

    def build_response_body(response_buf, errors)
      errors &&= errors.map do |error|
        {
          "reason" => error.reason.is_a?(Symbol) ? ":#{error.reason}" : error.reason,
          "pointer" => error.pointer && error.pointer.dump
        }
      end

      JSON.dump({
        "response_buf_b64" => response_buf && Base64.strict_encode64(response_buf),
        "errors" => errors
      })
    end
  end

  class << self
    def from_hash(hash)
      if (new_url = hash[:url])
        url(new_url)
      end

      if (new_path = hash[:path])
        path(new_path)
      end

      if (new_secret = hash[:secret])
        secret(new_secret)
      end
    end

    def url(url = nil)
      if url
        @url = url
        @path = URI(url).path
      end

      @url || raise(DefinitionError, "url is not defined")
    end

    def path(path = nil)
      @path = path if path
      @path || raise(DefinitionError, "path is not defined")
    end

    def secret(secret = nil)
      @secret = secret if secret
      @secret || raise(DefinitionError, "secret is not defined")
    end

    def call(service_name, request_buf)
      headers = build_headers
      request_body = build_request_body(service_name, request_buf)
      response_body = make_http_request(headers, request_body)
      response = decode_response_body(response_body)

      if response["response_buf_b64"]
        handle_success(response["response_buf_b64"])
      elsif response["errors"]
        handle_failure(response["errors"])
      else
        raise(TransportError, "malformed response: #{response.inspect}")
      end
    end

    private

    def build_headers
      { "X-RPC-Secret" => secret }
    end

    def build_request_body(service_name, request_buf)
      JSON.dump({
        "service_name" => service_name,
        "request_buf_b64" => Base64.strict_encode64(request_buf)
      })
    end

    def make_http_request(headers, body)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http_request = Net::HTTP::Post.new(uri.path, headers)
      http_request.body = body
      http_response = http.request(http_request)

      unless http_response.is_a?(Net::HTTPSuccess)
        raise(TransportError, "HTTP request failed with code #{http_response.code}")
      end

      http_response.body
    rescue SystemCallError => e
      raise(TransportError, e.to_s)
    end

    def decode_response_body(response_body)
      JSON.parse(response_body)
    end

    def handle_success(response_buf_b64)
      response_buf = Base64.strict_decode64(response_buf_b64)

      [response_buf, nil]
    end

    def handle_failure(errors)
      errors = errors.map do |error_from_json|
        reason_string = error_from_json["reason"]
        reason = reason_string =~ /^\:/ ? reason_string[1..-1].to_sym : reason_string
        pointer = error_from_json["pointer"]

        ServiceError.new(
          reason: reason,
          pointer: pointer && Pointer.new(nil, "request").load(pointer)
        )
      end

      [nil, errors]
    end
  end
end
end
end
