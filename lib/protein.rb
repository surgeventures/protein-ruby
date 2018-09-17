require "protein/logger"
require "protein/errors"
require "protein/proto_compiler"
require "protein/get_const"

require "protein/config"
require "protein/router"
require "protein/client"
require "protein/server"
require "protein/processor"
require "protein/payload"

require "protein/pointer"
require "protein/service_error"
require "protein/service"

require "protein/http_adapter"
require "protein/amqp_adapter"
require "protein/transport"

require "google/protobuf"
begin
  require "bunny"
rescue LoadError
end

module Protein
class << self
  def configure(&block)
    new_config = Config.new
    block.call(new_config)
    @config = new_config
    @config
  end

  def config
    @config ||= Config.new
  end

  def logger
    @logger ||= begin
      Protein::Logger.new($stdout).tap do |log|
        log.progname = 'protein'
      end
    end
  end
end
end
