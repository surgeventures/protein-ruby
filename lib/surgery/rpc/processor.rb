module Surgery
module RPC
class Processor
  class << self
    def call(router, request_payload)
      service_name, request_buf = Payload::Request.decode(request_payload)

      Rails.logger.info "Processing RPC call: #{service_name}"

      start_time = Time.now
      response_buf, errors = process(router, service_name, request_buf)
      duration_ms = ((Time.now - start_time) * 1000).round

      Rails.logger.info "#{response_buf ? 'Resolved' : 'Rejected'} in #{duration_ms}ms"

      Payload::Response.encode(response_buf, errors)
    end

    private

    def process(router, service_name, request_buf)
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
