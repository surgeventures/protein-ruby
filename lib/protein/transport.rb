module Protein
class Transport
  class << self
    def define(transport, opts = {})
      case transport
      when Class, String
        transport_class
      when Symbol
        transport_base_class =
          case transport
          when :http
            Protein::HTTPAdapter
          when :amqp
            Protein::AMQPAdapter
          else
            raise(DefinitionError, "invalid transport: #{transport.inspect}")
          end

        Class.new(transport_base_class).tap do |klass|
          klass.from_hash(opts)
        end
      else
        raise(DefinitionError, "invalid transport definition")
      end
    end
  end
end
end
