module Surgery
module RPC
class Processor
  class << self
    def call(router, service_name, request_buf)
      service_class = router.resolve_by_name(service_name)
      request_class = service_class.request_class
      request = request_class.decode(request_buf)
      service_instance = service_class.new(request)
      service_instance.process

      if service_instance.success?
        response_class = service_class.response_class
        response_buf = response_class.encode(service_instance.response)

        [response_buf, nil]
      else
        [nil, service_instance.errors]
      end
    end
  end
end
end
end
