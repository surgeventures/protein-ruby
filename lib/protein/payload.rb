require "net/http"
require "json"
require "base64"

module Protein
module Payload
  class Request
    class << self
      def encode(service_name, request_buf, request_metadata)
        JSON.dump({
          "service_name" => service_name,
          "request_metadata" => request_metadata,
          "request_buf_b64" => Base64.strict_encode64(request_buf)
        })
      end

      def decode(payload)
        hash = JSON.parse(payload)
        service_name = hash["service_name"]
        request_metadata = hash["request_metadata"] || Hash.new()
        request_buf_b64 = hash["request_buf_b64"]
        request_buf = Base64.strict_decode64(request_buf_b64)

        [service_name, request_buf, request_metadata]
      end
    end
  end

  class Response
    class << self
      def encode(response_buf, errors, response_metadata)
        JSON.dump({
          "response_buf_b64" => response_buf && Base64.strict_encode64(response_buf),
          "response_metadata" => response_metadata,
          "errors" => encode_errors(errors)
        })
      end

      def decode(payload)
        hash = JSON.parse(payload)
        response_buf_b64 = hash["response_buf_b64"]
        response_buf = response_buf_b64 && Base64.strict_decode64(response_buf_b64)
        errors = hash["errors"]
        errors = errors && decode_errors(errors)
        response_metadata = hash["response_metadata"] || Hash.new()

        [response_buf, errors, response_metadata]
      end

      private

      def encode_errors(errors)
        errors && errors.map do |error|
          {
            "reason" => error.reason.is_a?(Symbol) ? ":#{error.reason}" : error.reason,
            "pointer" => error.pointer && error.pointer.dump
          }
        end
      end

      def decode_errors(errors)
        errors && errors.map do |error|
          reason_string = error["reason"]
          reason = reason_string =~ /^\:/ ? reason_string[1..-1].to_sym : reason_string
          pointer = error["pointer"]

          ServiceError.new(
            reason: reason,
            pointer: pointer && Pointer.new(nil, "request").load(pointer)
          )
        end
      end
    end
  end
end
end
