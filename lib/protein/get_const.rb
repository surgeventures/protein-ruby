module Protein
class GetConst
  class << self
    def call(input)
      if input.is_a?(String)
        Object.const_get(input)
      elsif input != nil
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
