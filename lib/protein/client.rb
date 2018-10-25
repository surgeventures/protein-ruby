require 'date'
require "securerandom"

module Protein
class Client
  class << self
    def route(router)
      @router = Router.define(router)
    end

    def service(service)
      @router ||= Class.new(Router)
      @router.service(service)
    end

    def proto(proto)
      service = Class.new(Service)
      service.proto(proto)

      @router ||= Class.new(Router)
      @router.service(service)
    end

    def router
      GetConst.call(@router)
    end

    def transport(transport, opts = {})
      @transport_class = Transport.define(transport, opts)
    end

    def transport_class
      GetConst.call(@transport_class)
    end

    def call(request)
      service_class = router.resolve_by_request(request)

      raise(ArgumentError, "called to non-responding service") unless service_class.response?

      service_name = service_class.service_name
      request_class = service_class.request_class
      request_buf = request_class.encode(request)
      request_metadata = generate_request_metadata(service_name)
      request_payload = Payload::Request.encode(service_name, request_buf, request_metadata)

      Protein.logger.info "Calling RPC service: #{service_name}", request_metadata
      request_sent_timestamp = DateTime.now.strftime("%Q").to_i
      response_payload = transport_class.call(request_payload)
      response_arrival_timestamp = DateTime.now.strftime("%Q").to_i

      response_buf, errors, response_metadata = Payload::Response.decode(response_payload)

      response_metadata["response_arrival_timestamp"] = response_arrival_timestamp
      Protein.logger.info "Received RPC response in #{response_arrival_timestamp - request_sent_timestamp}", response_metadata

      service_instance = service_class.new(request)

      if response_buf
        response = service_class.response_class.decode(response_buf)
        service_instance.resolve(response)
      elsif errors
        service_instance.reject(errors)
      end

      service_instance
    end

    def call!(request)
      service_instance = call(request)
      if service_instance.failure?
        raise(CallError, service_instance.errors)
      end

      service_instance.response
    end

    def push(request)
      service_class = router.resolve_by_request(request)

      raise(ArgumentError, "pushed to responding service") if service_class.response?

      service_name = service_class.service_name
      request_class = service_class.request_class
      request_buf = request_class.encode(request)
      request_metadata = generate_request_metadata(service_name)
      request_payload = Payload::Request.encode(service_name, request_buf, request_metadata)

      transport_class.push(request_payload)

      nil
    end

    def generate_request_metadata()
      {
        service_name: service_name,
        request_id: SecureRandom.uuid,
        request_timestamp: DateTime.now.strftime("%Q").to_i
      }
    end
  end
end
end
