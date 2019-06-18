require 'spec_helper'

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
  end

  class Router < Protein::Router
    service "RPC::TestService"
  end
  class Client < Protein::Client
    transport :amqp,
      url: ENV['AMQP_URL'],
      queue: "test_rpc"

    route "RPC::Router"
  end
end

RSpec.describe "AMQP transport integration" do
  subject(:client) do
    RPC::Client
  end

  it "works" do
    expect(
      client.call(RPC::TestCall::Request.new(counter: 123)).response['incremented_counter']
    ).to eq 0
  end
end