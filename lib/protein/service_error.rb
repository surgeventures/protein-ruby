module Protein
class ServiceError
  attr_reader :reason
  attr_accessor :pointer

  def initialize(reason: nil, pointer: nil)
    @reason = reason if reason
    @pointer = pointer if pointer

    unless @reason.is_a?(String) || @reason.is_a?(Symbol)
      raise(ProcessingError, "error reason must be a string or symbol")
    end
  end
end
end
