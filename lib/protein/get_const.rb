module Protein
class GetConst
  class << self
    def call(input)
      case input
      when nil
        raise DefinitionError, "unset required option"
      when String
        Object.const_get(input)
      else
        input
      end
    end

    def map(array)
      array.map(&method(:call))
    end
  end
end
end
