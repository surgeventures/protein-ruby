module Protein
class Service
  class << self
    def service(service_name)
      @service_name = service_name
    end

    def service_name
      @service_name || raise(DefinitionError, "service name is not defined")
    end

    def proto(proto_module = nil)
      @proto_module = proto_module
      @service_name ||= proto_module.to_s.split("::").last.
        scan(/[A-Z][^A-Z]*/).map(&:downcase).join("_")
      @request_class ||= "#{proto_module}::Request"
      @response_class ||= "#{proto_module}::Response"
    end

    def proto_module
      GetConst.call(@proto_module)
    end

    def request(request_class)
      @request_class = request_class
    end

    def request_class
      GetConst.call(@request_class)
    end

    def response?
      response_class != false &&
        (!response_class.is_a?(String) || !(Object.const_get(response_class) rescue nil).nil?)
    rescue NameError
      false
    end

    def response(response_class)
      @response_class = response_class
    end

    def response_class
      GetConst.call(@response_class)
    end
  end

  attr_reader :request, :response, :errors

  def initialize(request)
    @request = request
  end

  def response?
    self.class.response?
  end

  def response_class
    self.class.response_class
  end

  def process
    @success = nil
    @response = response_class.new if response?
    @errors = []

    call

    raise(ProcessingError, "resolve/reject must be called") if response? && @success.nil?
  end

  def resolve(response = nil)
    raise(ProcessingError, "can't resolve non-responding service") unless response?
    raise(ProcessingError, "unable to resolve with previous errors") if @errors && @errors.any?

    @success = true
    @response =
      if !response
        @response
      elsif response.is_a?(response_class)
        response
      else
        response_class.new(response)
      end
  end

  def reject(*args)
    raise(ProcessingError, "can't reject non-responding service") unless response?
    if args.any? && @errors && @errors.any?
      raise(ProcessingError, "unable to reject with both rejection value and previous errors")
    end

    @success = false
    @errors =
      if args.empty? && @errors && @errors.any?
        @errors
      elsif args.empty?
        [build_error(:error)]
      elsif args.length == 1 && args[0].is_a?(Array) && args[0].any?
        args[0].map { |error| build_error(error) }
      else
        [build_error(*args)]
      end
  end

  def success?
    raise(ProcessingError, "resolve/reject must be called first") if @success.nil?

    @success
  end

  def failure?
    !success?
  end

  def add_error(*args)
    @errors << build_error(*args)
  end

  private

  def build_error(*args)
    if args[0].is_a?(String) || args[0].is_a?(Symbol)
      reason = args[0]
      pointer =
        if args[1].is_a?(Hash) && (at = args[1][:at])
          Pointer.new(request, "request", at)
        end

      ServiceError.new(reason: reason, pointer: pointer)
    elsif args[0].is_a?(ServiceError)
      args[0]
    elsif args[0].is_a?(Hash)
      ServiceError.new(reason: args[0][:reason], pointer: args[0][:pointer])
    end
  end
end
end
