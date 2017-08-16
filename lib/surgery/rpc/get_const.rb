module Surgery
module RPC
class GetConst
  class << self
    def call(input)
      if input.is_a?(String)
        input.constantize
      elsif input
        input
      else
        raise DefinitionError, "unset required option"
      end
    end

    def map(array)
      array.map { |input| call(input) }
    end
  end
end
end
end
