require 'spec_helper'
require_relative 'rpc_contract'

module RPC
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

  it "successfully calls amqp server" do
    expect(
      client.call(
        RPC::TestCall::Request.new(counter: 123)
      ).response['incremented_counter']
    ).to eq 124
  end
end
