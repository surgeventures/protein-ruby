module Surgery
module RPC
  class CallError < StandardError
    def initialize(errors)
      super(
        errors.map do |error|
          error.reason.inspect + (error.pointer ? " (at #{error.pointer})" : "")
        end.join(", ")
      )
    end
  end
  class DefinitionError < StandardError; end
  class PointerError < StandardError; end
  class ProcessingError < StandardError; end
  class RoutingError < StandardError; end
  class TransportError < StandardError; end
end
end
