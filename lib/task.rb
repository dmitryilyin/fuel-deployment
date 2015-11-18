require 'error'
require 'node'
require 'set'
require 'log'

module Deployment
  class Task
    ALLOWED_STATUSES = [:pending, :successful, :failed, :skipped, :running]

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

    def reset
      @dependencies_are_ready = nil
      @dependencies_have_failed = nil
      reset_forward
    end

    def reset_forward
      each_forward_dependency do |task|
        task.reset
      end
    end

    def node=(node)
      fail Deployment::InvalidArgument, "#{self}: Not a node used instead of the task node" unless node.is_a? Deployment::Node
      @node = node
    end

    def name=(name)
      @name = name.to_s
    end

    def status=(value)
      value = value.to_sym
      fail Deployment::InvalidArgument, "#{self}: Invalid task status: #{value}" unless ALLOWED_STATUSES.include? value
      @status = value
      reset_forward if [:failed, :successful].include? value
      @status
    end

    ALLOWED_STATUSES.each do |status|
      method_name = "set_status_#{status}".to_sym
      define_method(method_name) do
        self.status = status
      end
    end

    def dependency_backward_add(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      backward_dependencies.add task
      task.forward_dependencies.add self
      reset
    end

    alias :requires :dependency_backward_add
    alias :depends :dependency_backward_add
    alias :after :dependency_backward_add

    alias :dependency_add :dependency_backward_add
    alias :add_dependency :dependency_backward_add

    def dependency_forward_add(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      forward_dependencies.add task
      task.backward_dependencies.add self
      reset
    end

    alias :is_required :dependency_forward_add
    alias :depended_on :dependency_forward_add
    alias :before :dependency_forward_add

    def dependency_backward_remove(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      backward_dependencies.delete task
      task.forward_dependencies.delete self
      reset
    end

    alias :remove_requires :dependency_backward_remove
    alias :remove_depends :dependency_backward_remove
    alias :remove_after :dependency_backward_remove

    alias :dependency_remove :dependency_backward_remove
    alias :remove_dependency :dependency_backward_remove

    def dependency_forward_remove(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      forward_dependencies.delete task
      task.backward_dependencies.delete self
      reset
    end

    alias :remove_is_required :dependency_forward_remove
    alias :remove_depended_on :dependency_forward_remove
    alias :remove_before :dependency_forward_remove

    def dependency_backward_present?(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      backward_dependencies.member? task and task.forward_dependencies.member? self
    end

    alias :has_requires? :dependency_backward_present?
    alias :has_depends? :dependency_backward_present?
    alias :has_after? :dependency_backward_present?

    alias :dependency_present? :dependency_backward_present?
    alias :has_dependency? :dependency_backward_present?

    def dependency_forward_present?(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      forward_dependencies.member? task and task.backward_dependencies.member? self
    end

    alias :has_is_required? :dependency_forward_present?
    alias :has_depended_on? :dependency_forward_present?
    alias :has_before? :dependency_forward_present?

    def dependency_backward_any?
      backward_dependencies.any?
    end

    alias :any_backward_dependency? :dependency_backward_any?

    alias :dependency_any? :dependency_backward_any?
    alias :any_dependency? :dependency_backward_any?

    def dependency_forward_any?
      forward_dependencies.any?
    end

    alias :any_forward_dependencies? :dependency_forward_any?

    def each_backward_dependency(&block)
      backward_dependencies.each(&block)
    end

    alias :each :each_backward_dependency
    alias :each_dependency :each_backward_dependency

    def each_forward_dependency(&block)
      forward_dependencies.each(&block)
    end

    def dependencies_are_ready?
      return @dependencies_are_ready unless @dependencies_are_ready.nil?
      return false if @dependencies_have_failed
      ready = all? do |task|
        task.successful? or task.skipped?
      end
      debug 'All dependencies are ready' if ready
      @dependencies_are_ready = ready
    end

    def dependencies_have_failed?
      return @dependencies_have_failed unless @dependencies_have_failed.nil?
      failed = select do |task|
        task.failed?
      end
      debug "Found failed dependencies: #{failed.map { |t| t.name }.join ', '}" if failed.any?
      @dependencies_have_failed = failed.any?
    end

    def finished?
      failed? or successful? or skipped?
    end

    def successful?
      status == :successful
    end

    def pending?
      status == :pending
    end

    alias :new? :pending?

    def running?
      status == :running
    end

    def skipped?
      status == :skipped
    end

    def ready?
      pending? and not dependencies_have_failed? and dependencies_are_ready?
    end

    def failed?
      status == :failed or dependencies_have_failed?
    end

    def to_s
      "Task[#{node.name}/#{name}]"
    end

    def inspect
      message = "#{self}"
      message += " Status: #{status} DepsReady: #{dependencies_are_ready?} DepsFailed: #{dependencies_have_failed?}"
      message += " After: #{dependency_backward_names.join ', '}" if dependency_backward_any?
      message += " Before: #{dependency_forward_names.join ', '}" if dependency_forward_any?
      message
    end

    def dependency_backward_names
      names = []
      each_backward_dependency do |task|
        names << "#{task.name}(#{task.node.name})"
      end
      names
    end

    alias :dependency_names :dependency_backward_names

    def dependency_forward_names
      names = []
      each_forward_dependency do |task|
        names << "#{task.name}(#{task.node.name})"
      end
      names
    end

    def run
      info "Run on node: #{node}"
      @status = :running
      node.run self
    end

  end
end
