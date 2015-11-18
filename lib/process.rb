require 'log'

module Deployment
  class Process

    def initialize(*nodes)
      self.nodes = nodes.flatten
      @id = nil
    end

    include Enumerable
    include Deployment::Log

    attr_reader :nodes
    attr_accessor :id

    def self.[](*nodes)
      Deployment::Process.new *nodes
    end

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
      info 'Starting the deployment process'
      loop do
        if all_nodes_are_successful?
          info 'All nodes are deployed successfully - Stopping the deployment process'
          break true
        end
        if all_nodes_are_finished?
          info 'All nodes are finished with different statuses - Stopping the deployment process'
          break false
        end
        process_all_nodes
      end
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

    def tasks_total_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_total_count
      end
    end

    def tasks_failed_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_failed_count
      end
    end

    def tasks_successful_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_successful_count
      end
    end

    def tasks_finished_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_finished_count
      end
    end

    def tasks_pending_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_pending_count
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
      message += " Tasks: #{tasks_finished_count}/#{tasks_total_count} Nodes: #{map { |node| node.name }.join ', '}" if nodes.any?
      message
    end
  end
end
