module Protein
class Processor
  class << self
    def call(router, request_payload)
      service_name, request_buf, request_metadata = Payload::Request.decode(request_payload)
      service_class = router.resolve_by_name(service_name)

      if service_class.response?
        process_and_log_call(service_name, service_class, request_buf, request_metadata)
      else
        process_and_log_push(service_name, service_class, request_buf, request_metadata)
      end
    end

    private

    def process_and_log_call(service_name, service_class, request_buf, request_metadata)
      Protein.logger.info "Processing RPC call: #{service_name}", request_metadata

      start_time = Time.now
      response_buf, errors, response_metadata = process_call(service_class, request_buf, request_metadata)
      duration_ms = ((Time.now - start_time) * 1000).round

      Protein.logger.info "#{response_buf ? 'Resolved' : 'Rejected'} in #{duration_ms}ms", request_metadata

      Payload::Response.encode(response_buf, errors, response_metadata) if service_class.response?
    end

    def process_call(service_class, request_buf, request_metadata)
      request_class = service_class.request_class
      request = request_class.decode(request_buf)
      service_instance = service_class.new(request)

      service_instance.process

      response_metadata = get_response_metadata_with_defaults(request_metadata, service_instance.response_metadata)

      if service_instance.success?
        response_class = service_class.response_class
        response_buf = response_class.encode(service_instance.response)

        [response_buf, nil, response_metadata]
      else
        [nil, service_instance.errors, response_metadata]
      end
    end

    def process_and_log_push(service_name, service_class, request_buf, request_metadata)
      Protein.logger.info "Processing RPC push: #{service_name}", request_metadata

      start_time = Time.now
      process_push(service_class, request_buf)
      duration_ms = ((Time.now - start_time) * 1000).round

      Protein.logger.info "Processed in #{duration_ms}ms", request_metadata

      nil
    end

    def process_push(service_class, request_buf)
      request_class = service_class.request_class
      request = request_class.decode(request_buf)
      service_instance = service_class.new(request)

      service_instance.process
    end

    def get_response_metadata_with_defaults(request_metadata, response_metadata)
      default_metadata = {
        "request_id" => SecureRandom.uuid,
      }

      metadata = default_metadata.merge(request_metadata)
      metadata["timestamp"] = DateTime.now.strftime("%Q").to_i

      metadata.merge(response_metadata)
    end
  end
end
end
