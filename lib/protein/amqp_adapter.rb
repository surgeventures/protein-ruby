require "bunny"
require "securerandom"
require "thread"

module Protein
class AMQPAdapter
  class << self
    def from_hash(hash)
      if (new_url = hash[:url])
        url(new_url)
      end

      if (new_queue = hash[:queue])
        queue(new_queue)
      end

      if hash.has_key?(:timeout)
        timeout(hash[:timeout])
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

    def timeout(timeout = :not_set)
      @timeout = timeout if timeout != :not_set
      instance_variable_defined?("@timeout") ? @timeout : 15_000
    end

    attr_reader :reply_queue
    attr_accessor :response, :call_id
    attr_reader :lock, :condition

    def call(request_payload)
      prepare_client

      @call_id = SecureRandom.uuid

      @x.publish(request_payload,
        correlation_id: @call_id,
        routing_key: @server_queue,
        reply_to: @reply_queue.name,
        expiration: timeout)

      self.response = nil
      lock.synchronize { condition.wait(lock, timeout && timeout * 0.001) }

      if response == nil
        raise(TransportError, "timeout after #{timeout}ms")
      elsif response == "ESRV"
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
      @conn = Bunny.new(url)
      @conn.start
      @ch = @conn.create_channel
      @q = @ch.queue(queue)
      @x = @ch.default_exchange

      Protein.logger.info "Connected to #{url}, serving RPC calls from #{queue}"

      loop do
        begin
          @q.subscribe(block: true, manual_ack: true) do |delivery_info, properties, payload|
            begin
              @error = nil
              response = Processor.call(router, payload)
            rescue Exception => error
              @error = error
              response = "ESRV"
            end

            if response
              @x.publish(response,
                routing_key: properties.reply_to,
                correlation_id: properties.correlation_id)
            end

            @ch.ack(delivery_info.delivery_tag)

            if @error
              error_logger = Protein.config.error_logger
              error_logger.call(@error) if error_logger

              raise(@error)
            end
          end
        rescue StandardError => e
          Protein.logger.error "RPC server error: #{e.inspect}, restarting the server in 5s..."

          sleep 5
        end
      end
    end

    private

    def prepare_client
      return if @conn

      @conn = Bunny.new(url)
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
