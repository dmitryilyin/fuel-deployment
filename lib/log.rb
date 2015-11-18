require 'error'
require 'logger'

module Deployment
  module Log
    def self.logger
      return @logger if @logger
      @logger = Logger.new STDOUT
    end

    def self.logger=(value)
      unless value.respond_to? :debug and value.respond_to? :warn and value.respond_to? :info
        raise Deployment::InvalidArgument, 'The object does not look like a logger'
      end
      @logger = value
    end

    def debug(message)
      Deployment::Log.logger.debug "#{self}: #{message}"
    end

    def warn(message)
      Deployment::Log.logger.warn "#{self}: #{message}"
    end

    def info(message)
      Deployment::Log.logger.info "#{self}: #{message}"
    end

  end
end
