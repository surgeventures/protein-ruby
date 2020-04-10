require 'protein'
require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "test_call.Request" do
    optional :counter, :uint32, 1
  end

  add_message "test_call.Response" do
    optional :incremented_counter, :uint32, 1
  end
end

module RPC
  module TestCall
    Request = Google::Protobuf::DescriptorPool.generated_pool.lookup("test_call.Request").msgclass
    Response = Google::Protobuf::DescriptorPool.generated_pool.lookup("test_call.Response").msgclass
  end

  class TestService < Protein::Service
    proto "RPC::TestCall"

    def call
      resolve(incremented_counter: request.counter + 1)
    end
  end

  class Router < Protein::Router
    config(around_processing: ->(block) { block.call })

    service "RPC::TestService"
  end
end
