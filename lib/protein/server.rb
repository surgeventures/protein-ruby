require 'parallel'

module Protein
class Server
  class << self
    def route(router)
      @router = Router.define(router)
    end

    def service(service)
      @router ||= Class.new(Router)
      @router.service(service)
    end

    def router
      GetConst.call(@router)
    end

    def config(config = nil)
      @config = (@config || {}).merge(config) if config
      @config || {}
    end

    def transport(transport, opts = {})
      @transport_class = Transport.define(transport, opts)
    end

    def transport_class
      GetConst.call(@transport_class)
    end

    def start
      worker_count = config.fetch(:concurrency, 5)
      on_worker_boot = config[:on_worker_boot]

      if worker_count.is_a?(Integer) && worker_count > 1
        Parallel.each(1..worker_count, in_processes: worker_count) do |worker|
          Protein.logger.info "Starting server #{worker}/#{worker_count} with PID #{Process.pid}"
          on_worker_boot.call if on_worker_boot.respond_to?(:call)
          transport_class.serve(router)
        end
      else
        transport_class.serve(router)
      end
    end
  end
end
end
