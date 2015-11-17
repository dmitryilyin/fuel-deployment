require 'error'
require 'node'
require 'set'

module Deployment
  class Task
    ALLOWED_STATUSES = [:pending, :successful, :failed, :skipped, :running]

    def initialize(name, node)
      self.name = name
      @status = :pending
      @required = Set.new
      @dependencies_are_ready = false
      @dependencies_have_failed = false
      self.node = node
    end

    include Enumerable

    attr_reader :name
    attr_reader :node
    attr_reader :status
    attr_reader :required

    def reset
      @dependencies_are_ready = false
      @dependencies_have_failed = false
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
    end

    ALLOWED_STATUSES.each do |status|
      method_name = "set_status_#{status}".to_sym
      define_method(method_name) do
        self.status = status
      end
    end

    def dependency_add(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      required.add task
      reset
    end
    alias :add_dependency :dependency_add
    alias :depends :dependency_add

    def dependency_remove(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      required.delete task
      reset
    end
    alias :remove_dependency :dependency_remove

    def dependency_present?(task)
      fail Deployment::InvalidArgument, "#{self}: Dependency should be a task" unless task.is_a? Task
      required.member? task
    end
    alias :has_dependency? :dependency_present?

    def dependencies_any?
      required.any?
    end
    alias :any_dependencies? :dependencies_any?

    def each_dependency(&block)
      required.each(&block)
    end
    alias :each :each_dependency

    # Dependencies checks #

    def dependencies_are_ready?
      return true if @dependencies_are_ready
      return false if @dependencies_have_failed
      ready = all? do |task|
        task.successful?
      end
      if ready
        debug 'All dependencies are ready'
        @dependencies_are_ready = true
      end
      ready
    end

    def dependencies_have_failed?
      return true if @dependencies_have_failed
      failed = select do |task|
        task.failed?
      end
      if failed.any?
        debug "Found failed dependencies: #{failed.map { |t| t.name }.join ', '}"
        @dependencies_have_failed = true
      end
      failed.any?
    end

    def finished?
      [:successful, :failed, :skipped].include? status
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
      "Task[#{name}]"
    end

    def inspect
      list_of_dependencies = map do |task|
        "#{task.name}(#{task.node.name})"
      end
      report = [
          "Task[#{name}]",
          "Status: #{status}"
      ]
      report << "Required: #{list_of_dependencies.join ', '}" if list_of_dependencies.any?
      report.join ' '
    end

    def debug(message)
      log "#{self}: #{message}"
    end

    def run
      debug "Run on node: #{node}"
      @status = :running
      node.run self
    end

    def log(message)
      # override this in a subclass
      puts message
    end

  end
end
