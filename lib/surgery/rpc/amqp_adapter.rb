require "bunny"
require "thread"

module Surgery
module RPC
class AMQPAdapter
  class << self
    def from_hash(hash)
      if (new_url = hash[:url])
        url(new_url)
      end

      if (new_queue = hash[:queue])
        queue(new_queue)
      end

      if (new_timeout = hash[:timeout])
        timeout(new_timeout)
      end
    end

    def url(url = nil)
      @url = url if url
      @url || raise(DefinitionError, "url is not defined")
    end

    def queue(queue = nil)
      @queue = queue if queue
      @queue || raise(DefinitionError, "queue is not defined")
    end

    def timeout(timeout = nil)
      @timeout = timeout if timeout
      @timeout || 15_000
    end

    attr_reader :reply_queue
    attr_accessor :response, :call_id
    attr_reader :lock, :condition

    def call(request_payload)
      prepare_client

      @call_id = SecureRandom.uuid

      Rails.logger.debug "Sending request #{@call_id}"

      @x.publish(request_payload,
        correlation_id: @call_id,
        routing_key: @server_queue,
        reply_to: @reply_queue.name,
        expiration: timeout == 0 ? nil : timeout)

      self.response = nil
      lock.synchronize { condition.wait(lock, timeout == 0 ? nil : timeout * 0.001) }

      if response == nil
        raise(TransportError, "timeout after #{timeout}ms")
      elsif response == "service_error"
        raise(TransportError, "failed to process the request")
      else
        response
      end
    end

    def push(message_payload)
      prepare_client

      @x.publish(message_payload,
        routing_key: @server_queue)
    end

    def serve(router)
      Rails.logger.info "Connecting to #{url.inspect}"

      @conn = Bunny.new(url)
      @conn.start
      @ch = @conn.create_channel

      Rails.logger.info "Preparing queue #{queue.inspect}"

      @q = @ch.queue(queue)
      @x = @ch.default_exchange

      Rails.logger.info "Serving RPC calls"

      @q.subscribe(block: true) do |delivery_info, properties, payload|
        Rails.logger.info "Processing request #{properties.correlation_id}"

        begin
          @error = nil
          response = Processor.call(router, payload)
        rescue StandardError => error
          @error = error
          response = "service_error"
        end

        if response
          @x.publish(response,
            routing_key: properties.reply_to,
            correlation_id: properties.correlation_id)
        end

        raise(@error) if @error
      end
    end

    private

    def prepare_client
      return if @conn

      Rails.logger.info "Connecting to #{url.inspect}"

      @conn = Bunny.new(url, automatically_recover: false)
      @conn.start
      @ch = @conn.create_channel
      @x = @ch.default_exchange
      @server_queue = queue
      @reply_queue = @ch.queue("", exclusive: true)
      @lock = Mutex.new
      @condition = ConditionVariable.new

      that = self

      @reply_queue.subscribe do |delivery_info, properties, payload|
        if properties[:correlation_id] == that.call_id
          that.response = payload
          that.lock.synchronize{that.condition.signal}
        end
      end
    end
  end
end
end
end
