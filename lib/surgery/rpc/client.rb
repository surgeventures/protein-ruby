module Surgery
module RPC
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
      service_name = service_class.service_name
      request_class = service_class.request_class
      request_buf = request_class.encode(request)
      response_buf, errors = transport_class.call(service_name, request_buf)
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
  end
end
end
end
