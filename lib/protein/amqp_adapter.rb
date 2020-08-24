require "securerandom"

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

      if hash.key?(:timeout)
        timeout(hash[:timeout])
      end

      if hash.key?(:heartbeat)
        heartbeat(hash[:heartbeat])
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
      @timeout = timeout unless timeout == :not_set
      instance_variable_defined?("@timeout") ? @timeout : 15_000
    end

    def heartbeat(heartbeat = 10)
      @heartbeat ||= heartbeat
    end

    def init
      @connection_mutex = Mutex.new
    end

    attr_reader :reply_queue
    attr_accessor :calls

    def call(request_payload)
      prepare_client

      call_id = SecureRandom.uuid

      @x.publish request_payload,
        correlation_id: call_id,
        routing_key: @server_queue,
        reply_to: @reply_queue.name,
        expiration: timeout

      mutex = Mutex.new
      condition = ConditionVariable.new
      call = Concurrent::Hash.new
      call[:mutex] = mutex
      call[:condition] = condition
      calls[call_id] = call

      mutex.synchronize do
        condition.wait(mutex, timeout && timeout * 0.001)
      end

      response = call[:response]
      calls.delete(call_id)

      case response
      when nil
        raise TransportError, "timeout after #{timeout}ms"
      when "ESRV"
        raise TransportError, "failed to process the request"
      else
        response
      end
    end

    def push(message_payload)
      prepare_client

      @x.publish message_payload,
        routing_key: @server_queue,
        persistent: true
    end

    def serve(router)
      @terminating = false
      @processing = false

      @conn = Bunny.new(url, heartbeat: heartbeat)
      begin
        @conn.start
      rescue Bunny::TCPConnectionFailed => e
        Protein.logger.error "RPC server connection error: #{e.inspect}"
        log_error(e)
        raise(e)
      end

      @ch = @conn.create_channel
      @ch.prefetch(1)
      begin
        @q = @ch.queue(queue, durable: true)
        Protein.logger.info "Declared queue #{queue} as durable"
      rescue Bunny::PreconditionFailed => e
        Protein.logger.debug(e.inspect)

        @ch = @conn.create_channel
        @ch.prefetch(1)
        @q = @ch.queue(queue, durable: false)
        Protein.logger.info "Declared queue #{queue} as non-durable (fallback-mode)"
      end
      @x = @ch.default_exchange

      Signal.trap("TERM") do
        if @processing
          @terminating = true
        else
          exit
        end
      end

      Signal.trap("INT") do
        if @processing
          @terminating = true
        else
          exit
        end
      end

      Protein.logger.info "Connected to #{url}, serving RPC calls from #{queue}"

      loop do
        begin
          @q.subscribe(block: true, manual_ack: true) do |delivery_info, properties, payload|
            @processing = true

            begin
              @error = nil
              response = Processor.call(router, payload)
            rescue Exception => error
              @error = error
              response = "ESRV"
            end

            if response
              @x.publish response,
                routing_key: properties.reply_to,
                correlation_id: properties.correlation_id
            end

            @ch.ack(delivery_info.delivery_tag)
            @processing = false

            break if @terminating

            if @error
              log_error(@error)
              raise(@error)
            end
          end
        rescue StandardError => e
          @processing = false

          break if @terminating

          log_error(e)
          Protein.logger.error "RPC server error: #{e.inspect}, restarting the server in 5s..."

          sleep 5
        end
      end
    end

    private

    def log_error(error)
      @error_logger ||= Protein.config.error_logger
      @error_logger.call(error) if @error_logger
    end

    def prepare_client
      state = @connection_mutex.synchronize do
        next :running if defined?(@conn)

        @conn = Bunny.new(url, heartbeat: heartbeat)
        @conn.start
        @ch = @conn.create_channel
        @x = @ch.default_exchange
        @server_queue = queue
        @reply_queue = @ch.queue("", exclusive: true)
        @calls = Concurrent::Hash.new

        :initialized
      end

      return if state == :running

      @reply_queue.subscribe do |_delivery_info, properties, payload|
        call_id = properties[:correlation_id]
        call = calls[call_id]

        if call
          mutex = call[:mutex]
          condition = call[:condition]
          call[:response] = payload

          mutex.synchronize { condition.signal }
        end
      end
    end
  end
end
end
