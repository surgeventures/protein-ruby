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
      resolve(incremented_counter: 0)
    end
  end

  class Router < Protein::Router
    service "RPC::TestService"
  end

  class Server < Protein::Server
    transport :amqp,
      url: ENV['AMQP_URL'],
      queue: "test_rpc"
    
    config(concurrency: 1, on_worker_boot: -> {})
    
    route "RPC::Router"
  end
  
  class Client < Protein::Client
    transport :amqp,
      url: ENV['AMQP_URL'],
      queue: "test_rpc"

    route "RPC::Router"
  end
end

RPC::Server.start