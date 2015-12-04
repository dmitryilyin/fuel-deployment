require 'fuel-deployment/gv'

module Deployment

  # The Process object controls the deployment flow.
  # It loops through the nodes and runs tasks on then
  # when the node is ready and the task is available.
  #
  # attr [Object] id Misc identifier of this process
  class Process

    # @param [Array<Deployment::Node>] nodes The array of nodes to deploy
    def initialize(*nodes)
      self.nodes = nodes.flatten
      @id = nil
    end

    include Enumerable
    include Deployment::Log
    include Deployment::GV

    attr_reader :nodes
    attr_accessor :id

    # Create the Process object with these nodes
    # @param [Array<Deployment::Node>] nodes The array of nodes to deploy
    def self.[](*nodes)
      self.new(*nodes)
    end

    # Set a new nodes array
    # @raise Deployment::InvalidArgument If this is not an array or it consists not only of Nodes
    # @param [Array<Deployment::Node>] nodes The array of nodes to deploy
    # @return Deployment::Node
    def nodes=(nodes)
      fail Deployment::InvalidArgument, "#{self}: Nodes should be an array" unless nodes.is_a? Array
      fail Deployment::InvalidArgument, "#{self}: Nodes should contain only Node objects" unless nodes.all? { |n| n.is_a? Deployment::Node }
      @nodes = nodes
    end

    # Iterates through all nodes
    # @yield Deployment::Node
    def each_node(&block)
      nodes.each(&block)
    end
    alias :each :each_node

    # Iterates through all the tasks on all nodes
    # @yield Deployment::Task
    def each_task
      return to_enum(:each_task) unless block_given?
      each_node do |node|
        node.each_task do |task|
          yield task
        end
      end
    end

    # Check if graphs have a closed loop
    # @return [true, false]
    def has_loop?
      begin
        topology_sort
        false
      rescue Deployment::LoopDetected
        true
      end
    end

    # Topology sort all tasks in all graphs
    # Tarjan's algorithm
    # @return [Array<Deployment::Task>]
    # @raise
    def topology_sort
      topology = []
      permanently_visited = Set.new
      temporary_visited = []
      loop do
        task = each_task.find do |task|
          not (permanently_visited.include? task or temporary_visited.include? task)
        end
        return topology unless task
        visit task, topology, permanently_visited, temporary_visited
      end
      topology
    end

    # Tarjan's Algorithm visit function
    # @return [Array<Deployment::Task>]
    # @raise Deployment::LoopDetected If a loop is detected in the graph
    # These parameters are carried through the recursion calls:
    # @param [Array<Deployment::Task>] topology A list of topologically sorted tasks
    # @param [Set<Deployment::Task>] permanently_visited Set of permanently visited tasks
    # @param [Array<Deployment::Task>] temporary_visited List of temporary visited tasks
    def visit(task, topology = [], permanently_visited = Set.new, temporary_visited = [])
      if temporary_visited.include? task
        # This node have already been visited in this small iteration and
        # it means that there is a loop.
        temporary_visited << task
        visited = temporary_visited.join ', '
        raise Deployment::LoopDetected, "#{self}: Loop detected! Path: #{visited}"
      end
      if permanently_visited.include? task
        # We have already checked this node for loops in
        # its forward dependencies. Skip it.
        return
      end
      # Start a small iteration over this node's forward dependencies
      # add this node to the last iteration visit list and run recursion
      # on the forward dependencies
      temporary_visited << task
      task.each_forward_dependency do |forward_task|
        visit forward_task, topology, permanently_visited, temporary_visited
      end
      # Small iteration have completed without loops.
      # We add this node to the list of permanently marked nodes and
      # remove in from the temporary marked nodes list.
      permanently_visited.add task
      temporary_visited.delete task
      # Insert this node to the head of topology sort list and return it.
      topology.insert 0, task
    end

    # Process a single node when it's visited.
    # First, poll the node's status nad leave it the node is not ready.
    # Then try to get a next task from the node and run it, or leave, if
    # there is none available.
    # @param [Deployment::Node] node
    # @return [void]
    def process_node(node)
      debug "Process node: #{node}"
      node.poll
      return unless node.online?
      ready_task = node.ready_task
      return unless ready_task
      ready_task.run
    end

    # Loops once through all nodes and processes each one
    # @return [void]
    def process_all_nodes
      debug 'Start processing all nodes'
      each_node do |node|
        process_node node
      end
    end

    # Run this deployment process.
    # It will loop through all nodes running task
    # until the deployment will be considered finished.
    # Deployment is finished if all the nodes have all tasks finished
    # successfully, or finished with other statuses.
    # Actually, it's enough to check only for finished nodes.
    # @return [true, false]
    def run
      info 'Starting the deployment process'
      topology_sort

      loop do
        if all_nodes_are_successful?
          info 'All nodes are deployed successfully. Stopping the deployment process'
          break true
        end
        if has_failed_critical_nodes?
          failed_names = failed_critical_nodes.map { |n| n.name }.join ', '
          info "Critical nodes failed: #{failed_names}. Stopping the deployment process."
          break false
        end
        if all_nodes_are_finished?
          if has_failed_nodes?
            failed_names = failed_nodes.map { |n| n.name }.join ', '
            info "All nodes are finished and some have failed: #{failed_names}. Stopping the deployment process."
          else
            info 'All nodes are finished. Stopping the deployment process.'
          end
          break false
        end

        # run loop over all nodes
        process_all_nodes
      end
    end

    # Get the list of critical nodes
    # @return [Array<Deployment::Node>]
    def critical_nodes
      select do |node|
        node.critical?
      end
    end

    # Get the list of critical nodes that have failed
    # @return [Array<Deployment::Node>]
    def failed_critical_nodes
      critical_nodes.select do |node|
        node.failed?
      end
    end

    # Check if there are some critical nodes
    # that have failed
    # @return [true, false]
    def has_failed_critical_nodes?
      failed_critical_nodes.any?
    end

    # Get the list of the failed nodes
    # @return [Array<Deployment::Node>]
    def failed_nodes
      select do |node|
        node.failed?
      end
    end

    # Check if some nodes are failed
    # @return [true, false]
    def has_failed_nodes?
      failed_nodes.any?
    end

    # Check if all nodes are finished
    # @return [true, false]
    def all_nodes_are_finished?
      all? do |node|
        node.finished?
      end
    end

    # Check if all nodes are successful
    # @return [true, false]
    def all_nodes_are_successful?
      all? do |node|
        node.successful?
      end
    end

    # Count the total task number on all nodes
    # @return [Integer]
    def tasks_total_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_total_count
      end
    end

    # Count the total number of the failed tasks
    # @return [Integer]
    def tasks_failed_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_failed_count
      end
    end

    # Count the total number of the successful tasks
    # @return [Integer]
    def tasks_successful_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_successful_count
      end
    end

    # Count the total number of the finished tasks
    # @return [Integer]
    def tasks_finished_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_finished_count
      end
    end

    # Count the total number of the pending tasks
    # @return [Integer]
    def tasks_pending_count
      inject(0) do |sum, node|
        sum + node.graph.tasks_pending_count
      end
    end

    # @return [String]
    def to_s
      "Process[#{id}]"
    end

    # @return [String]
    def inspect
      message = "#{self}"
      message += "{Tasks: #{tasks_finished_count}/#{tasks_total_count} Nodes: #{map { |node| node.name }.join ', '}}" if nodes.any?
      message
    end

  end
end
