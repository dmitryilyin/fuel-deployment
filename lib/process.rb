module Deployment
  class Process

    def initialize(id ,*nodes)
      self.nodes = nodes.flatten
      @id = id
    end

    def self.[](id, *nodes)
      Deployment::Process.new id, *nodes
    end

    attr_reader :nodes
    attr_accessor :id
    include Enumerable

    def nodes=(nodes)
      fail Deployment::InvalidArgument, "#{self}: Nodes should be an array" unless nodes.is_a? Array
      fail Deployment::InvalidArgument, "#{self}: Nodes should contain only Node objects" unless nodes.all? { |n| n.is_a? Deployment::Node }
      @nodes = nodes
    end

    def each_node(&block)
      nodes.each(&block)
    end
    alias :each :each_node

    def each_task
      return to_enum(:each_task) unless block_given?
      each_node do |node|
        node.each_task do |task|
          yield task
        end
      end
    end

    def process_node(node)
      debug "Process node: #{node}"
      node.poll
      return unless node.online?
      ready_task = node.ready_task
      return unless ready_task
      ready_task.run
    end

    def process_all_nodes
      debug 'Start processing all nodes'
      each_node do |node|
        process_node node
      end
    end

    def run
      loop do
        if all_nodes_are_successful?
          debug 'All nodes are deployed successfully. Stopping deployment process.'
          break
        end
        if all_nodes_are_finished?
          debug 'All nodes are finished with different statuses. Stopping deployment process.'
          break
        end
        process_all_nodes
      end
    end

    def log(message)
      # override this in a subclass
      puts message
    end

    def debug(message)
      log "#{self}: #{message}"
    end

    def all_nodes_are_finished?
      all? do |node|
        node.finished?
      end
    end

    def all_nodes_are_successful?
      all? do |node|
        node.successful?
      end
    end

    def some_nodes_are_failed?
      any? do |node|
        node.failed?
      end
    end

    def gv_load
      require 'gv'
      extend Deployment::GV
      self.gv_filter_node = nil
    end

    def to_s
      "Process[#{id}]"
    end

    def inspect
      message = "#{self}"
      message += " Nodes: #{map { |node| node.name }.join ', '}"  if nodes.any?
      message
    end
  end
end
