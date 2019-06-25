require 'spec_helper'
require_relative 'rpc_contract'

module RPC
  class HttpClient < Protein::Client
    transport :http,
      url: ENV['RPC_SERVER_URL'],
      secret: ENV['RPC_SECRET']

    route "RPC::Router"
  end

  class AmqpClient < Protein::Client
    transport :amqp,
      url: ENV['AMQP_URL'],
      queue: "test_rpc"

    route "RPC::Router"
  end
end

RSpec.shared_examples "client-server communication" do |injected_client|
  subject(:client) do
    injected_client
  end

  it "successfully calls server and receives response" do
    expect(
      client.call(
        RPC::TestCall::Request.new(counter: 123)
      ).response['incremented_counter']
    ).to eq 124
  end
end

RSpec.describe "AMQP transport integration" do
  it_behaves_like "client-server communication", RPC::AmqpClient
end

RSpec.describe "HTTP transport integration" do
  it_behaves_like "client-server communication", RPC::HttpClient
end
