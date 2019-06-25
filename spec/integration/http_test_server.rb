require_relative 'rpc_contract'

require 'rack'
require 'rack/show_exceptions'

Rack::Server.start(
  app: Protein::HTTPAdapter::Middleware.new(RPC::Router, ENV["RPC_SECRET"]),
  Host: '0.0.0.0',
  Port: '80'
)
