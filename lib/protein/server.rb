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

    def transport(transport, opts = {})
      @transport_class = Transport.define(transport, opts)
    end

    def transport_class
      GetConst.call(@transport_class)
    end

    def start
      transport_class.serve(router)
    end
  end
end
end
