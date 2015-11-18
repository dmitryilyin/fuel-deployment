lib_dir = File.join File.dirname(__FILE__), '../lib/'
lib_dir = File.absolute_path File.expand_path lib_dir
$LOAD_PATH << lib_dir

require 'task'
require 'node'
require 'error'
require 'graph'
require 'process'
require 'log'

Deployment::Log.logger.level = Logger::INFO

module Deployment
  class TestNode < Node
    def run(task)
      fail Deployment::InvalidArgument, "#{self}: Node can run only tasks" unless task.is_a? Deployment::Task
      debug "Run task: #{task}"
      self.task = task
      self.status = :busy
    end

    def poll
      debug 'Poll node status'
      if busy?
        status = :successful
        debug "#{task} finished with: #{status}"
        self.task.status = status
        self.status = :online
      end
    end
  end
end
