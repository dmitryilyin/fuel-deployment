lib_dir = File.join File.dirname(__FILE__), '../lib'
lib_dir = File.absolute_path File.expand_path lib_dir
$LOAD_PATH << lib_dir

require 'rubygems'
require 'deployment'

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

  class PlotProcess < Process
    # loop once through all nodes and process them
    def process_all_nodes
      debug 'Start processing all nodes'
      each_node do |node|
        process_node node
        gv_load
        gv_make_step_image
      end
    end
  end
end
