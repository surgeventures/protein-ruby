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
      @transport_class.init
    end

    def transport_class
      GetConst.call(@transport_class)
    end

    def start
      worker_count = config.fetch(:concurrency, 5)
      on_worker_boot = config[:on_worker_boot]

      pids = (1..worker_count).map do |i|
        fork do
          Protein.logger.info "Starting server #{i}/#{worker_count} with PID #{Process.pid}"
          on_worker_boot.call if on_worker_boot.respond_to?(:call)
          transport_class.serve(router)
        end
      end

      Signal.trap('TERM') do
        pids.each { |pid| Process.kill(:TERM, pid) }
        pids.each { |pid| Process.wait(pid) }
      end

      Signal.trap('INT') do
        pids.each { |pid| Process.kill(:INT, pid) }
        pids.each { |pid| Process.wait(pid) }
      end

      Process.wait
    end
  end
end
end
