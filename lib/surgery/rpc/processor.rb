module Surgery
module RPC
class Processor
  class << self
    def call(router, request_payload)
      service_name, request_buf = Payload::Request.decode(request_payload)
      service_class = router.resolve_by_name(service_name)

      if service_class.response?
        process_and_log_call(service_name, service_class, request_buf)
      else
        process_and_log_push(service_name, service_class, request_buf)
      end
    end

    private

    def process_and_log_call(service_name, service_class, request_buf)
      Rails.logger.info "Processing RPC call: #{service_name}"

      start_time = Time.now
      response_buf, errors = process_call(service_class, request_buf)
      duration_ms = ((Time.now - start_time) * 1000).round

      Rails.logger.info "#{response_buf ? 'Resolved' : 'Rejected'} in #{duration_ms}ms"

      Payload::Response.encode(response_buf, errors) if service_class.response?
    end

    def process_call(service_class, request_buf)
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

    def process_and_log_push(service_name, service_class, request_buf)
      Rails.logger.info "Processing RPC push: #{service_name}"

      start_time = Time.now
      process_push(service_class, request_buf)
      duration_ms = ((Time.now - start_time) * 1000).round

      Rails.logger.info "Processed in #{duration_ms}ms"

      nil
    end

    def process_push(service_class, request_buf)
      request_class = service_class.request_class
      request = request_class.decode(request_buf)
      service_instance = service_class.new(request)

      service_instance.process
    end
  end
end
end
end
