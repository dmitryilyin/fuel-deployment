require 'task'

module Deployment
  class Graph
    def initialize(node)
      @tasks_have_failed = false
      @tasks_are_finished = false
      @tasks_are_successful = false
      self.node = node
      @tasks = {}
    end

    include Enumerable

    attr_reader :node
    attr_reader :tasks

    def reset
      @tasks_have_failed = false
      @tasks_are_finished = false
      @tasks_are_successful = false
    end

    def prepare_key(task)
      task = task.name if task.is_a? Deployment::Task
      task.to_s.to_sym
    end

    def task_get(task_name)
      tasks.fetch prepare_key(task_name), nil
    end
    alias :get_task :task_get
    alias :[] :task_get

    def task_add(task)
      fail Deployment::InvalidArgument, "#{self}: Graph can add only tasks" unless task.is_a? Deployment::Task
      return task_get task if task_present? task
      fail Deployment::InvalidArgument, "#{self}: Graph cannot add tasks not for this node" unless task.node == node
      tasks.store prepare_key(task), task
      reset
      task
    end
    alias :add_task :task_add

    def task_add_new(task_name)
      return task_get task_name if task_present? task_name
      task = Deployment::Task.new task_name, node
      task_add task
    end
    alias :add_new_task :task_add_new
    alias :new_task :task_add_new
    alias :create_task :task_add_new

    def task_present?(task_name)
      tasks.key? prepare_key(task_name)
    end
    alias :has_task? :task_present?
    alias :key? :task_present?

    def task_remove(task_name)
      return unless task_present? task_name
      tasks.delete prepare_key(task_name)
      reset
    end
    alias :remove_task :task_remove

    def dependency_add(task_from, task_to)
      unless task_from.is_a? Deployment::Task
        task_from = get_task task_from
        fail Deployment::NoSuchTask, "#{self}: There is no such task in the graph: #{task_from}" unless task_from
      end
      unless task_to.is_a? Deployment::Task
        task_to = get_task task_to
        fail Deployment::NoSuchTask, "#{self}: There is no such task in the graph: #{task_to}" unless task_to
      end
      task_to.dependency_add task_from
    end
    alias :add_dependency :dependency_add

    def node=(node)
      fail Deployment::InvalidArgument, "#{self}: Not a node used instead of the graph node" unless node.is_a? Deployment::Node
      @node = node
    end

    def name
      node.name
    end

    def each_task(&block)
      tasks.each_value(&block)
    end

    alias :each :each_task

    def tasks_are_finished?
      return true if @tasks_are_finished
      finished = all? do |task|
        task.finished?
      end
      if finished
        debug 'All tasks are finished'
        @tasks_are_finished = true
      end
      finished
    end
    alias :finished? :tasks_are_finished?

    def tasks_are_successful?
      return true if @tasks_are_successful
      return false if  @tasks_have_failed
      successful = all? do |task|
        task.successful?
      end
      if successful
        debug 'All tasks are successful'
        @tasks_are_successful = true
      end
      successful
    end
    alias :successful? :tasks_are_successful?

    def tasks_have_failed?
      return true if @tasks_have_failed
      failed = select do |task|
        task.failed?
      end
      if failed.any?
        debug "Found failed tasks: #{failed.map { |t| t.name }.join ', '}"
        @tasks_have_failed = true
      end
      failed.any?
    end
    alias :failed? :tasks_have_failed?

    def ready_task
      find do |task|
        task.ready?
      end
    end
    alias :next_task :ready_task

    def debug(message)
      log "#{self}: #{message}"
    end

    def log(message)
      # override this in a subclass
      puts message
    end

    def task_names
      map do |task|
        task.name
      end
    end

    def gv_load
      require 'gv'
      extend Deployment::GV
      self.gv_filter_node = node
    end

    def to_s
      "Graph[#{name}]"
    end

    def inspect
      "#{self} Tasks: #{tasks.length} Finished: #{tasks_are_finished?} Failed: #{tasks_have_failed?} Successful: #{tasks_are_successful?}"
    end
  end
end
