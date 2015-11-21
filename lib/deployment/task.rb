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
  class Task
    # a task can be in one of these statuses
    ALLOWED_STATUSES = [:pending, :successful, :failed, :skipped, :running]
    # these statuses can cause dependency status to change
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

    # reset the mnemoization of the task
    # @return [void]
    def reset
      @dependencies_are_ready = nil
      @dependencies_have_failed = nil
      reset_forward
    end

    # reset the mnemoization of this task's forward dependencies
    # @return [void]
    def reset_forward
      return unless dependency_forward_any?
      each_forward_dependency do |task|
        task.reset
      end
    end

    # set this task's Node object
    # @param [Deployment::Node] node The ne node object
    # @raise [Deployment::InvalidArgument] if the object is not a Node
    # @return [Deployment::Node]
    def node=(node)
      fail Deployment::InvalidArgument, "#{self}: Not a node used instead of the task node" unless node.is_a? Deployment::Node
      @node = node
    end

    # set the new task name
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
      @status = value
      reset_forward if DEPENDENCY_CHANGING_STATUSES.include? value
      @status
    end

    ALLOWED_STATUSES.each do |status|
      method_name = "set_status_#{status}".to_sym
      define_method(method_name) do
        self.status = status
      end
    end

    # add a new backward dependency - the task, required to run this task
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

    # add a new forward dependency - the task, that requires this task to run
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

    # remove a forward dependency of this task
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

    # check if this task is within the backward dependencies
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

    # check if this task is within the forward dependencies
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

    # check if there are any backward dependencies
    # @return [true, false]
    def dependency_backward_any?
      backward_dependencies.any?
    end
    alias :any_backward_dependency? :dependency_backward_any?
    alias :dependency_any? :dependency_backward_any?
    alias :any_dependency? :dependency_backward_any?

    # check if there are any forward dependencies
    # @return [true, false]
    def dependency_forward_any?
      forward_dependencies.any?
    end
    alias :any_forward_dependencies? :dependency_forward_any?

    # iterates through the backward dependencies
    # @yield [Deployment::Task]
    def each_backward_dependency(&block)
      backward_dependencies.each(&block)
    end
    alias :each :each_backward_dependency
    alias :each_dependency :each_backward_dependency

    # iterates through the forward dependencies
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

    # task have finished, successful or not, and
    # will not run again in this deployment
    # @return [true, false]
    def finished?
      failed? or successful? or skipped?
    end

    # task have successfully finished
    # @return [true, false]
    def successful?
      status == :successful
    end

    # task have not run yet
    # @return [true, false]
    def pending?
      status == :pending
    end
    alias :new? :pending?

    # task is running right now
    # @return [true, false]
    def running?
      status == :running
    end

    # task is manually skipped
    # @return [true, false]
    def skipped?
      status == :skipped
    end

    # task is ready to run, it has all dependencies met and is pending
    # @return [true, false]
    def ready?
      pending? and not dependencies_have_failed? and dependencies_are_ready?
    end

    # this task have been run but unsuccessfully
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

    # get a sorted list of all this task's dependencies
    # @return [Array<String>]
    def dependency_backward_names
      names = []
      each_backward_dependency do |task|
        names << task.to_s
      end
      names.sort
    end
    alias :dependency_names :dependency_backward_names

    # get a sorted list of all tasks that depend on this task
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
      @status = :running
      node.run self
    end

  end
end
