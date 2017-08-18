module Surgery
module RPC
class Transport
  class << self
    def define(transport, opts = {})
      if transport.is_a?(Class) || transport.is_a?(String)
        transport_class
      elsif transport.is_a?(Symbol)
        transport_base_class =
          case transport
          when :http
            Surgery::RPC::HTTPAdapter
          else
            raise(DefinitionError, "invalid transport: #{transport.inspect}")
          end

        transport_class = Class.new(transport_base_class)
        transport_class.from_hash(opts)
        transport_class
      else
        raise(DefinitionError, "invalid transport definition")
      end
    end
  end
end
end
end
