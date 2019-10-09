begin
  require "bunny"
rescue LoadError
end

require "concurrent"
require "google/protobuf"

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

module Protein
class << self
  def configure
    @config = Config.new.tap do |new_config|
      yield new_config
    end
  end

  def config
    @config ||= Config.new
  end

  def logger
    @logger ||= Logger.new($stdout).tap do |log|
      log.progname = "protein"
      log.level = config.log_level || :info
    end
  end
end
end
