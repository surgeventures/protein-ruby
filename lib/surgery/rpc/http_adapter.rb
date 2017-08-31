require "net/http"
require "json"

module Surgery
module RPC
class HTTPAdapter
  HTTPS_SCHEME = "https".freeze

  class Middleware
    def initialize(router, secret)
      @router = router
      @secret = secret
    end

    def call(env)
      check_secret(env)

      request_payload = env["rack.input"].read
      service_name, request_buf = Payload::Request.decode(request_payload)

      Rails.logger.info "Processing RPC call: #{service_name}"

      start_time = Time.now
      response_buf, errors = Processor.call(@router, service_name, request_buf)
      duration_ms = ((Time.now - start_time) * 1000).round

      Rails.logger.info "#{response_buf ? 'Resolved' : 'Rejected'} in #{duration_ms}ms"

      response_payload = Payload::Response.encode(response_buf, errors)

      ["200", {}, [response_payload]]
    end

    private

    def check_secret(env)
      return if @secret == env["HTTP_X_RPC_SECRET"]

      raise(TransportError, "invalid secret")
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

    def call(request_payload)
      make_http_request(request_payload, build_headers())
    end

    private

    def build_headers
      { "X-RPC-Secret" => secret }
    end

    def make_http_request(body, headers)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == HTTPS_SCHEME
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
  end
end
end
end
