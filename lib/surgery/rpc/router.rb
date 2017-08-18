module Surgery
module RPC
class Router
  class << self
    def define(router)
      if router.is_a?(Class) || router.is_a?(String)
        router
      elsif router.is_a?(Hash)
        router_class = Class.new(Router)
        router_class.from_hash(router)
        router_class
      else
        raise(DefinitionError, "invalid router definition")
      end
    end

    def from_hash(hash)
      if hash[:services]
        hash[:services].each do |each_service|
          service(each_service)
        end
      end

      if hash[:protos]
        hash[:protos].each do |each_proto|
          service_class = Class.new(Service)
          service_class.proto(each_proto)

          service(service_class)
        end
      end
    end

    def service(service_class)
      @services ||= []
      @services << service_class
    end

    def services
      GetConst.map(@services || [])
    end

    def resolve_by_name(service_name)
      services.find do |service|
        service.service_name == service_name.to_s
      end || raise(RoutingError, "service #{service_name.inspect} not found")
    end

    def resolve_by_request(request)
      services.find do |service|
        request.is_a?(service.request_class)
      end || raise(RoutingError, "service for #{request.class} not found")
    end
  end
end
end
end
