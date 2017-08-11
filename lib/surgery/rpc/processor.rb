module Surgery
module RPC
class Processor
  class << self
    def route(router)
      @router = Router.define(router)
    end

    def service(service)
      @router ||= Class.new(Router)
      @router.service(service)
    end

    def router
      @router || raise(DefinitionError, "router class is not defined")
    end

    def transport(transport, opts = {})
      @transport_class = Transport.define(transport, opts)
    end

    def transport_class
      @transport_class || raise(DefinitionError, "transport class is not defined")
    end

    def call(service_name, request_buf)
      service_class = router.resolve_by_name(service_name)

      Rails.logger.info "Processing by #{service_class}"

      start_time = Time.now
      request_class = service_class.request_class
      request = request_class.decode(request_buf)
      service_instance = service_class.new(request)
      service_instance.process
      duration_ms = ((Time.now - start_time) * 1000).round

      if service_instance.success?
        response_class = service_class.response_class
        response_buf = response_class.encode(service_instance.response)

        Rails.logger.info "Resolved in #{duration_ms}ms"

        [response_buf, nil]
      else
        Rails.logger.info "Rejected in #{duration_ms}ms"

        [nil, service_instance.errors]
      end
    end
  end
end
end
end
