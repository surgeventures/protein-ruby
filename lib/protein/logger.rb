module Protein
  class Logger < Logger
    def add_with_metadata(severity, metadata, message = nil, progname = nil, &block)
      if message.nil?
        progname = message_with_metadata(progname, metadata)
      else
        message = message_with_metadata(message, metadata)
      end

      add(severity, message, progname, &block)
    end

    def debug(progname = nil, metadata = nil, &block)
      add_with_metadata(DEBUG, metadata, nil, progname, &block)
    end

    def error(progname = nil, metadata = nil, &block)
      add_with_metadata(ERROR, metadata, nil, progname, &block)
    end

    def fatal(progname = nil, metadata = nil, &block)
      add_with_metadata(FATAL, metadata, nil, progname, &block)
    end

    def info(progname = nil, metadata = nil, &block)
      add_with_metadata(INFO, metadata, nil, progname, &block)
    end

    def unknown(progname = nil, metadata = nil, &block)
      add_with_metadata(UNKNOWN, metadata, nil, progname, &block)
    end

    def warn(progname = nil, metadata = nil, &block)
      add_with_metadata(WARN, metadata, nil, progname, &block)
    end

    private

    def message_with_metadata(message, metadata)
      return message if metadata.nil?
      [message, *metadata.map{|k,v| "#{k}=#{v}"}].join(" ")
    end
  end
end
