lib_dir = File.join File.dirname(__FILE__), '../lib'
lib_dir = File.absolute_path File.expand_path lib_dir
$LOAD_PATH << lib_dir

require 'rubygems'
require 'fuel-deployment'
require 'optparse'
require 'pry'

Deployment::Log.logger.level = Logger::INFO

def options
  return $options if $options
  $options = {}
  OptionParser.new do |opts|
    opts.on('-p', '--plot') do |value|
      options[:plot] = value
    end
    opts.on('-f', '--fail') do |value|
      options[:fail] = value
    end
    opts.on('-c', '--critical') do |value|
      options[:critical] = value
    end
    opts.on('-i', '--interactive') do |value|
      options[:interactive] = value
    end
    opts.on('-d', '--debug') do
      Deployment::Log.logger.level = Logger::DEBUG
    end
  end.parse!
  $options
end

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
    def hook_post_node(*args)
      gv_make_step_image
    end
  end
end
