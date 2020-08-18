require "drb/drb"

module Protein
class ServerHealthCheck
  def initialize(worker_health_check_ports)
    @worker_health_check_ports = worker_health_check_ports
  end

  def healthy?
    @worker_health_check_ports.all? do |health_check_port|
      begin
        worker_health_check_url = "druby://localhost:#{health_check_port}"
        worker_health_check = DRbObject.new_with_uri(worker_health_check_url)
        worker_health_check.healthy?
      rescue StandardError => e
        Protein.logger.error e
        false
      end
    end
  end
end

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
      health_check_port = config[:health_check_port]
      worker_health_check_ports = []

      pids = (1..worker_count).map do |i|
        worker_health_check_port = health_check_port ? health_check_port + i : nil
        worker_health_check_ports << worker_health_check_port

        fork do
          Protein.logger.info "Starting server #{i}/#{worker_count} with PID #{Process.pid}"
          on_worker_boot.call if on_worker_boot.respond_to?(:call)

          transport_class.serve(
            router,
            health_check_port: worker_health_check_port
          )
        end
      end

      Signal.trap("TERM") do
        pids.each { |pid| Process.kill(:TERM, pid) }
        pids.each { |pid| Process.wait(pid) }
      end

      Signal.trap("INT") do
        pids.each { |pid| Process.kill(:INT, pid) }
        pids.each { |pid| Process.wait(pid) }
      end

      if health_check_port
        DRb.start_service(
          "druby://localhost:#{health_check_port}",
          ::Protein::ServerHealthCheck.new(worker_health_check_ports)
        )
        Protein.logger.info "ServerHealthCheck DRuby service listening on port #{health_check_port}"
      end

      Process.wait
    end
  end
end
end
