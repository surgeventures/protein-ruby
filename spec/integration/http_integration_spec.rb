require 'spec_helper'
require_relative 'rpc_contract'

module RPC
  class Client < Protein::Client
    transport :http,
      url: ENV['RPC_SERVER_URL'],
      secret: ENV['RPC_SECRET']

    route "RPC::Router"
  end
end

RSpec.describe "HTTP transport integration" do
  subject(:client) do
    RPC::Client
  end

  it "successfully calls http server" do
    expect(
      client.call(
        RPC::TestCall::Request.new(counter: 123)
      ).response['incremented_counter']
    ).to eq 124
  end
end
