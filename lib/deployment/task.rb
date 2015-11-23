require 'set'

module Deployment

  # The Task object represents a single deployment action.
  # It should be able to store information of it dependencies and
  # the tasks that depend on it. It should also be able to check if
  # the dependencies are ready so this task can be run or check if
  # there are some failed dependencies.
  # Task should maintain it's own status and have both name
  # and data payload attributes. Task is always assigned to a node
  # object that will be used to run it.
  #
  # @attr [String] name The task name
  # @attr [Deployment::Node] node The node object of this task
  # @attr [Symbol] status The status of this task
  # @attr_reader [Set<Deployment::Task>] backward_dependencies The Tasks required to run this task
  # @attr_reader [Set<Deployment::Task>] forward_dependencies The Tasks that require this Task to run
  # @attr [Object] data The data payload of this task
  # @attr [Integer] maximum_concurrency The maximum number of this task's instances running on the different nodes at the same time
  # @attr [Integer] current_concurrency The number of currently running task with the same name on all nodes
  class Task
    # A task can be in one of these statuses
    ALLOWED_STATUSES = [:pending, :successful, :failed, :skipped, :running]
    # These statuses can cause dependency status to change
    # and if one of them is set, reset all forward dependencies
    DEPENDENCY_CHANGING_STATUSES = [:failed, :successful, :skipped]

    # @param [String,Symbol] name The name of this task
    # @param [Deployment::Node] node The task will be assigned to this node
    # @param [Object] data The data payload. It can be any object and contain any
    # information that will be required to actually run the task.
    def initialize(name, node, data=nil)
      self.name = name
      @status = :pending
      @backward_dependencies = Set.new
      @forward_dependencies = Set.new
      @dependencies_are_ready = nil
      @dependencies_have_failed = nil
      @data = data
      self.node = node
    end

    include Enumerable
    include Deployment::Log

    attr_reader :name
    attr_reader :node
    attr_reader :status
    attr_reader :backward_dependencies
    attr_reader :forward_dependencies
    attr_accessor :data

    # Reset the mnemoization of the task
    # @return [void]
    def reset
      @dependencies_are_ready = nil
      @dependencies_have_failed = nil
      reset_forward
    end

    # Reset the mnemoization of this task's forward dependencies
    # @return [void]
    def reset_forward
      return unless dependency_forward_any?
      each_forward_dependency do |task|
        task.reset
      end
    end

    # Set this task's Node object
    # @param [Deployment::Node] node The ne node object
    # @raise [Deployment::InvalidArgument] if the object is not a Node
    # @return [Deployment::Node]
    def node=(node)
      fail Deployment::InvalidArgument, "#{self}: Not a node used instead of the task node" unless node.is_a? Deployment::Node
      @node = node
    end

    # Set the new task name
    # @param [String, Symbol] name
    # @return [String]
    def name=(name)
      @name = name.to_s
    end

    # Set the new task status. The task status can influence the dependency
    # status of the tasks that depend on this task then they should be reset to allow them to update
    # their status too.
    # @param [Symbol, String] value
    # @raise [Deployment::InvalidArgument] if the status is not valid
    # @return [Symbol]
    def status=(value)
      value = value.to_s.to_sym
      fail Deployment::InvalidArgument, "#{self}: Invalid task status: #{value}" unless ALLOWED_STATUSES.include? value
      status_changes_concurrency @status, value
      @status = value
      reset_forward if DEPENDENCY_CHANGING_STATUSES.include? value
      @status
    end

    # Get the current concurrency value for a given task
    # or perform an action with this value.
    # @param [Deployment::Task, String, Symbol] task
    # @param [Symbol] action
    # @option action [Symbol] :inc Increase the value
    # @option action [Symbol] :dec Decrease the value
    # @option action [Symbol] :reset Set the value to zero
    # @option action [Symbol] :set Manually set the value
    # @param [Integer] value Manually set to this value
    # @return [Integer]
    def self.current_concurrency(task, action = :get, value = nil)
      @current_concurrency = {} unless @current_concurrency
      task = task.name if task.is_a? Deployment::Task
      key = task.to_sym
      @current_concurrency[key] = 0 unless @current_concurrency[key]
      return @current_concurrency[key] unless action
      if action == :inc
        @current_concurrency[key] += 1
      elsif action == :dec
        @current_concurrency[key] -= 1
      elsif action == :reset
        @current_concurrency[key] = 0
      elsif action == :set
        begin
          @current_concurrency[key] = Integer(value)
        rescue TypeError, ArgumentError
          raise Deployment::InvalidArgument, "#{self}: Current concurrency should be an integer number"
        end
      end
      @current_concurrency[key] = 0 if @current_concurrency[key] < 0
      @current_concurrency[key]
    end

    # Get or set the maximumx concurrency value for a given task.
    # Value is set if the second argument is provided.
    # @param [Deployment::Task, String, Symbol] task
    # @param [Integer, nil] value
    # @return [Integer]
    def self.maximum_concurrency(task, value = nil)
      @maximum_concurrency = {} unless @maximum_concurrency
      task = task.name if task.is_a? Deployment::Task
      key = task.to_sym
      @maximum_concurrency[key] = 0 unless @maximum_concurrency[key]
      return @maximum_concurrency[key] unless value
      begin
        @maximum_concurrency[key] = Integer(value)
      rescue TypeError, ArgumentError
        raise Deployment::InvalidArgument, "#{self}: Maximum concurrency should be an integer number"
      end
      @maximum_concurrency[key]
    end

    # Get the maximum concurrency
    # @return [Integer]
    def maximum_concurrency
      self.class.maximum_concurrency self
    end

    # Set the maximum concurrency
    # @param [Integer] value
    # @return [Integer]
    def maximum_concurrency=(value)
      self.class.maximum_concurrency self, value
    end

    # Increase or decrease the concurrency value
    # when the task's status is changed.
    # @param [Symbol] status_from
    # @param [Symbol] status_to
    # @return [void]
    def status_changes_concurrency(status_from, status_to)
      return unless maximum_concurrency_is_set?
      if status_to == :running
        current_concurrency_increase
        info "Increasing concurrency to: #{current_concurrency}"
      elsif status_from == :running
        current_concurrency_decrease
        info "Decreasing concurrency to: #{current_concurrency}"
      end
    end

    # Get the current concurrency
    # @return [Integer]
    def current_concurrency
      self.class.current_concurrency self
    end

    # Increase the current concurrency by one
    # @return [Integer]
    def current_concurrency_increase
      self.class.current_concurrency self, :inc
    end

    # Decrease the current concurrency by one
    # @return [Integer]
    def current_concurrency_decrease
      self.class.current_concurrency self, :dec
    end

    # Reset the current concurrency to zero
    # @return [Integer]
    def current_concurrency_reset
      self.class.current_concurrency self, :reset
    end

    # Manually set the current concurrency value
    # @param [Integer] value
    # @return [Integer]
    def current_concurrency=(value)
      self.class.current_concurrency self, :set, value
    end

    # Check if there are concurrency slots available
    # to run this task.
    # @return [true, false]
    def concurrency_available?
      return true unless maximum_concurrency_is_set?
      current_concurrency < maximum_concurrency
    end

    # Check if the maximum concurrency of this task is set
    # @return [true, false]
    def maximum_concurrency_is_set?
      maximum_concurrency > 0
    end

    ALLOWED_STATUSES.each do |status|
      method_name = "set_status_#{status}".to_sym
      define_method(method_name) do
        self.status = status
      end
    end

    # Add a new backward dependency - the task, required to run this task
    # @param [Deployment::Task] task
    # @raise [Deployment::InvalidArgument] if the task is not a Task object
    # @return [Deployment::Task]
    def dependency_backward_add(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      backward_dependencies.add task
      task.forward_dependencies.add self
      reset
      task
    end
    alias :requires :dependency_backward_add
    alias :depends :dependency_backward_add
    alias :after :dependency_backward_add
    alias :dependency_add :dependency_backward_add
    alias :add_dependency :dependency_backward_add

    # Add a new forward dependency - the task, that requires this task to run
    # @param [Deployment::Task] task
    # @raise [Deployment::InvalidArgument] if the task is not a Task object
    # @return [Deployment::Task]
    def dependency_forward_add(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      forward_dependencies.add task
      task.backward_dependencies.add self
      reset
      task
    end
    alias :is_required :dependency_forward_add
    alias :depended_on :dependency_forward_add
    alias :before :dependency_forward_add

    # remove a backward dependency of this task
    # @param [Deployment::Task] task
    # @raise [Deployment::InvalidArgument] if the task is not a Task object
    # @return [Deployment::Task]
    def dependency_backward_remove(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      backward_dependencies.delete task
      task.forward_dependencies.delete self
      reset
      task
    end
    alias :remove_requires :dependency_backward_remove
    alias :remove_depends :dependency_backward_remove
    alias :remove_after :dependency_backward_remove
    alias :dependency_remove :dependency_backward_remove
    alias :remove_dependency :dependency_backward_remove

    # Remove a forward dependency of this task
    # @param [Deployment::Task] task
    # @raise [Deployment::InvalidArgument] if the task is not a Task object
    # @return [Deployment::Task]
    def dependency_forward_remove(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      forward_dependencies.delete task
      task.backward_dependencies.delete self
      reset
      task
    end
    alias :remove_is_required :dependency_forward_remove
    alias :remove_depended_on :dependency_forward_remove
    alias :remove_before :dependency_forward_remove

    # Check if this task is within the backward dependencies
    # @param [Deployment::Task] task
    # @raise [Deployment::InvalidArgument] if the task is not a Task object
    # @return [Deployment::Task]
    def dependency_backward_present?(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      backward_dependencies.member? task and task.forward_dependencies.member? self
    end
    alias :has_requires? :dependency_backward_present?
    alias :has_depends? :dependency_backward_present?
    alias :has_after? :dependency_backward_present?
    alias :dependency_present? :dependency_backward_present?
    alias :has_dependency? :dependency_backward_present?

    # Check if this task is within the forward dependencies
    # @param [Deployment::Task] task
    # @raise [Deployment::InvalidArgument] if the task is not a Task object
    # @return [Deployment::Task]
    def dependency_forward_present?(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      forward_dependencies.member? task and task.backward_dependencies.member? self
    end
    alias :has_is_required? :dependency_forward_present?
    alias :has_depended_on? :dependency_forward_present?
    alias :has_before? :dependency_forward_present?

    # Check if there are any backward dependencies
    # @return [true, false]
    def dependency_backward_any?
      backward_dependencies.any?
    end
    alias :any_backward_dependency? :dependency_backward_any?
    alias :dependency_any? :dependency_backward_any?
    alias :any_dependency? :dependency_backward_any?

    # Check if there are any forward dependencies
    # @return [true, false]
    def dependency_forward_any?
      forward_dependencies.any?
    end
    alias :any_forward_dependencies? :dependency_forward_any?

    # Iterates through the backward dependencies
    # @yield [Deployment::Task]
    def each_backward_dependency(&block)
      backward_dependencies.each(&block)
    end
    alias :each :each_backward_dependency
    alias :each_dependency :each_backward_dependency

    # Iterates through the forward dependencies
    # @yield [Deployment::Task]
    def each_forward_dependency(&block)
      forward_dependencies.each(&block)
    end

    # Check if all backward dependencies of this task are ready
    # so that this task can run.
    # The result is memorised until the task is reset.
    # Dependency is considered met if the task is successful or skipped
    # @return [true, false]
    def dependencies_are_ready?
      return @dependencies_are_ready unless @dependencies_are_ready.nil?
      return false if @dependencies_have_failed
      ready = all? do |task|
        task.successful? or task.skipped?
      end
      debug 'All dependencies are ready' if ready
      @dependencies_are_ready = ready
    end

    # Check if all some backward dependencies are failed
    # so that this task can run.
    # The result is memorised until the task is reset.
    # @return [true, false]
    def dependencies_have_failed?
      return @dependencies_have_failed unless @dependencies_have_failed.nil?
      failed = select do |task|
        task.failed?
      end
      debug "Found failed dependencies: #{failed.map { |t| t.name }.join ', '}" if failed.any?
      @dependencies_have_failed = failed.any?
    end

    # The task have finished, successful or not, and
    # will not run again in this deployment
    # @return [true, false]
    def finished?
      failed? or successful? or skipped?
    end

    # The task have successfully finished
    # @return [true, false]
    def successful?
      status == :successful
    end

    # The task was not run yet
    # @return [true, false]
    def pending?
      status == :pending
    end
    alias :new? :pending?

    # The task is running right now
    # @return [true, false]
    def running?
      status == :running
    end

    # The task is manually skipped
    # @return [true, false]
    def skipped?
      status == :skipped
    end

    # The task is ready to run,
    # it has all dependencies met and is in pending status
    # If the task has maximum concurrency set, it is checked too.
    # @return [true, false]
    def ready?
      pending? and not dependencies_have_failed? and dependencies_are_ready? and concurrency_available?
    end

    # This task have been run but unsuccessfully
    # @return [true, false]
    def failed?
      status == :failed or dependencies_have_failed?
    end

    # @return [String]
    def to_s
      "Task[#{node.name}/#{name}]"
    end

    # @return [String]
    def inspect
      message = "#{self}"
      message += " Status: #{status} DepsReady: #{dependencies_are_ready?} DepsFailed: #{dependencies_have_failed?}"
      message += " After: #{dependency_backward_names.join ', '}" if dependency_backward_any?
      message += " Before: #{dependency_forward_names.join ', '}" if dependency_forward_any?
      message
    end

    # Get a sorted list of all this task's dependencies
    # @return [Array<String>]
    def dependency_backward_names
      names = []
      each_backward_dependency do |task|
        names << task.to_s
      end
      names.sort
    end
    alias :dependency_names :dependency_backward_names

    # Get a sorted list of all tasks that depend on this task
    # @return [Array<String>]
    def dependency_forward_names
      names = []
      each_forward_dependency do |task|
        names << task.to_s
      end
      names.sort
    end

    # Run this task on its node.
    # This task will pass itself to the abstract run method of the Node object
    # and set it's status to 'running'.
    def run
      info "Run on node: #{node}"
      self.status = :running
      node.run self
    end

  end
end
