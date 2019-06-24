require_relative 'rpc_contract'

module RPC
  class Server < Protein::Server
    transport :amqp,
      url: ENV['AMQP_URL'],
      queue: "test_rpc"

    config(concurrency: 1, on_worker_boot: -> {})

    route "RPC::Router"
  end
end

RPC::Server.start