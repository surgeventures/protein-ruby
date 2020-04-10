module Protein
class Processor
  class << self
    DEFAULT_AROUND_PROCESSOR = -> (block) { block.call }

    def call(router, request_payload)
      around_processing = router.config.fetch(:around_processing) do
        DEFAULT_AROUND_PROCESSOR
      end

      response = nil

      service_name, request_buf = Payload::Request.decode(request_payload)
      service_class = router.resolve_by_name(service_name)

      around_processing.call(-> do
        response = if service_class.response?
          process_and_log_call(service_name, service_class, request_buf)
        else
          process_and_log_push(service_name, service_class, request_buf)
        end
      end, service_name, service_class)

      response
    end

    private

    def process_and_log_call(service_name, service_class, request_buf)
      start_time = Time.now
      response_buf, errors = process_call(service_class, request_buf)
      duration_ms = ((Time.now - start_time) * 1000).round

      Protein.logger.info(
        "RPC call #{service_name} #{response_buf ? 'resolved' : 'rejected'} in #{duration_ms}ms"
      )

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
      start_time = Time.now
      process_push(service_class, request_buf)
      duration_ms = ((Time.now - start_time) * 1000).round

      Protein.logger.info "RPC push #{service_name} processed in #{duration_ms}ms"

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
